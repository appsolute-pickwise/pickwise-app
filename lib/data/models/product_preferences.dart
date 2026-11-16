import 'product.dart';

class ProductPreferences {
  const ProductPreferences({
    this.priorities = const [],
    this.budget,
    this.wearType,
    this.requireAnc = false,
    this.maxWeightGrams,
    this.weights = const {},
    this.batteryCondition = 'ancOn',
  });

  static const ruleVersion = '2026-11-fair-v1';
  final String batteryCondition;
  final List<String> priorities;
  final String? budget;
  final String? wearType;
  final bool requireAnc;
  final double? maxWeightGrams;
  final Map<String, int> weights;

  int weightFor(String priority) => (weights[priority] ?? 3).clamp(1, 5);

  ProductPreferences withWeights(Map<String, int> values) => ProductPreferences(
    priorities: List.unmodifiable(priorities),
    budget: budget,
    wearType: wearType,
    requireAnc: requireAnc,
    maxWeightGrams: maxWeightGrams,
    weights: Map.unmodifiable(values),
    batteryCondition: batteryCondition,
  );

  Object? _spec(Product product, String key) {
    for (final spec in product.specs) {
      if (spec.key == key) return spec.value;
    }
    return null;
  }

  double? _number(Product product, String key) {
    final value = _spec(product, key);
    return value is num && value.isFinite && value > 0
        ? value.toDouble()
        : null;
  }

  List<String> exclusionReasons(Product product) {
    final reasons = <String>[];
    final inBudget = switch (budget) {
      '5만원 미만' => product.price < 50000,
      '5만~15만원' => product.price >= 50000 && product.price <= 150000,
      '15만원 초과' => product.price > 150000,
      _ => true,
    };
    final matchesWear =
        wearType == null ||
        (wearType == '귀걸이형'
            ? _spec(product, 'earHook') == true
            : _spec(product, 'wearType') == wearType);
    if (!inBudget) reasons.add('예산 범위');
    if (!matchesWear) reasons.add('착용 형태');
    if (requireAnc && _spec(product, 'anc') != true) reasons.add('ANC 필수');
    final weight = _number(product, 'weight');
    if (maxWeightGrams != null &&
        (weight == null || weight > maxWeightGrams!)) {
      reasons.add(weight == null ? '무게 정보 없음' : '한 쪽 ${maxWeightGrams}g 이하');
    }
    return reasons;
  }

  bool matches(Product product) => exclusionReasons(product).isEmpty;

  List<String> emptyResultReasons(List<Product> products) {
    final counts = <String, int>{};
    for (final product in products) {
      for (final reason in exclusionReasons(product)) {
        counts.update(reason, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return counts.entries
        .map((entry) => '${entry.key}: ${entry.value}개 제품 제외')
        .toList();
  }

  ProductSpecification? batteryFor(Product product) {
    if (batteryCondition == 'ancOn' && _spec(product, 'anc') == false) {
      return null;
    }
    final key = batteryCondition == 'normal'
        ? 'batteryHours'
        : 'batteryHoursAncOn';
    for (final spec in product.specs) {
      if (spec.key == key &&
          spec.value is num &&
          (spec.value as num) > 0 &&
          (spec.value as num).isFinite) {
        return spec;
      }
    }
    return null;
  }

  List<String> referenceReasons(Product product) => [
    for (final priority in priorities.toSet())
      if (switch (priority) {
        '배터리' => batteryFor(product) == null,
        '무게' => (_number(product, 'weight') ?? 0) <= 0,
        'ANC' => _spec(product, 'anc') is! bool,
        '방수' => !RegExp(
          r'^IP[0-6X][0-9]K?$',
        ).hasMatch('${_spec(product, 'waterResistance')}'),
        _ => false,
      })
        '$priority: ${priority == '배터리' ? '${batteryCondition == 'ancOn' ? 'ANC 켬' : '일반 재생'} 기준 ' : ''}정보가 없어요.',
  ];

  double? score(Product product) {
    if (referenceReasons(product).isNotEmpty) return null;
    double sum = 0, weightSum = 0;
    for (final priority in priorities.toSet()) {
      final double? value = switch (priority) {
        '배터리' =>
          ((batteryFor(product)!.value as num) / 12).clamp(0, 1).toDouble(),
        '무게' =>
          ((12 - _number(product, 'weight')!) / 10).clamp(0, 1).toDouble(),
        _ => null,
      };
      if (value != null) {
        sum += value * weightFor(priority);
        weightSum += weightFor(priority);
      }
    }
    return weightSum == 0 ? null : sum / weightSum;
  }

  List<Product> recommend(List<Product> products) {
    final candidates = products
        .where((p) => matches(p) && referenceReasons(p).isEmpty)
        .toList();
    candidates.sort((a, b) {
      final order = (score(b) ?? 0).compareTo(score(a) ?? 0);
      if (order != 0) return order;
      final price = a.price.compareTo(b.price);
      return price != 0 ? price : a.id.compareTo(b.id);
    });
    return candidates;
  }

  List<Product> referenceCandidates(List<Product> products) =>
      products
          .where((p) => matches(p) && referenceReasons(p).isNotEmpty)
          .toList()
        ..sort((a, b) {
          final c = a.price.compareTo(b.price);
          return c != 0 ? c : a.id.compareTo(b.id);
        });

  String get orderingExplanation =>
      priorities.any((p) => p == '배터리' || p == '무게')
      ? '같은 조건의 배터리·무게만 점수에 반영해요. 동점은 가격·제품 ID 순이에요.'
      : '계산할 수치 기준이 없어 가격·제품 ID 순이에요. ANC·방수는 성능 점수로 환산하지 않아요.';

  List<String> reasons(Product product) => [
    if (budget != null && matches(product)) '선택한 예산 범위에 들어요.',
    if (wearType != null && matches(product)) '$wearType 제품이에요.',
    if (requireAnc && _spec(product, 'anc') == true) '필수 조건인 ANC를 지원해요.',
    if (priorities.contains('배터리') && batteryFor(product) != null)
      '이어버드 ${batteryCondition == 'ancOn' ? 'ANC 켬' : '일반 재생'} 기준 최대 ${batteryFor(product)!.value}시간이에요.',
    if (priorities.contains('무게') && _number(product, 'weight') != null)
      '이어버드 한 쪽 무게는 ${_number(product, 'weight')}g이에요.',
    if (priorities.contains('ANC') && _spec(product, 'anc') is bool)
      'ANC ${_spec(product, 'anc') == true ? '지원' : '미지원'} · 성능 우열은 판단하지 않아요.',
    if (priorities.contains('방수') && _spec(product, 'waterResistance') != null)
      '방수 등급 ${_spec(product, 'waterResistance')} · 사용 조건을 확인해주세요.',
    ...referenceReasons(product),
    orderingExplanation,
  ];

  List<String> comparisonInsights(List<Product> products) {
    final result = <String>[orderingExplanation];
    if (products.length > 1) {
      final prices = [...products]..sort((a, b) => a.price.compareTo(b.price));
      final difference = prices.last.price - prices.first.price;
      if (difference > 0) {
        result.add(
          '등록 가격: ${prices.first.name}이(가) ${prices.last.name}보다 $difference원 낮아요. 각 가격 확인일 기준이에요.',
        );
      }
    }
    for (final key in priorities.toSet()) {
      if (key == 'ANC' || key == '방수') {
        result.add('$key: 등급·지원 정보이며 성능 순위를 의미하지 않아요.');
        continue;
      }
      double? number(Product p) => key == '배터리'
          ? (batteryFor(p)?.value as num?)?.toDouble()
          : _number(p, 'weight');
      if (products.any((p) => number(p) == null)) {
        result.add('$key: 같은 조건의 정보가 없어 우열 판단에서 제외했어요.');
        continue;
      }
      final sorted = [...products]
        ..sort(
          (a, b) => key == '무게'
              ? number(a)!.compareTo(number(b)!)
              : number(b)!.compareTo(number(a)!),
        );
      if (sorted.length < 2) continue;
      final diff = (number(sorted.first)! - number(sorted.last)!).abs();
      result.add(
        diff == 0
            ? '$key: 선택한 제품의 등록 수치가 같아요.'
            : '$key: ${sorted.first.name}이(가) ${sorted.last.name}보다 ${diff.toStringAsFixed(1)}${key == '무게' ? 'g 가벼워요.' : '시간 길어요 (${batteryCondition == 'ancOn' ? 'ANC 켬' : '일반 재생'}).'}',
      );
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
    'priorities': priorities,
    'budget': budget,
    'wearType': wearType,
    'requireAnc': requireAnc,
    'maxWeightGrams': maxWeightGrams,
    'weights': weights,
    'batteryCondition': batteryCondition,
  };
  factory ProductPreferences.fromJson(Map<String, dynamic> p) =>
      ProductPreferences(
        priorities: List<String>.from(p['priorities'] ?? []),
        budget: p['budget'] as String?,
        wearType: p['wearType'] as String?,
        requireAnc: p['requireAnc'] == true,
        maxWeightGrams: (p['maxWeightGrams'] as num?)?.toDouble(),
        weights: Map<String, int>.from(p['weights'] ?? {}),
        batteryCondition: p['batteryCondition'] as String? ?? 'ancOn',
      );
  ProductPreferences withBatteryCondition(String condition) =>
      ProductPreferences.fromJson({...toJson(), 'batteryCondition': condition});

  List<RelaxationSuggestion> relaxations(List<Product> products) {
    final options = <RelaxationSuggestion>[];
    for (final key in ['budget', 'maxWeightGrams', 'wearType', 'requireAnc']) {
      final value = toJson()[key];
      if (value == null || value == false) continue;
      final next = ProductPreferences.fromJson({
        ...toJson(),
        key: key == 'requireAnc' ? false : null,
      });
      final count = products.where(next.matches).length;
      if (count > 0) options.add(RelaxationSuggestion(key, next, count));
    }
    final order = ['budget', 'maxWeightGrams', 'wearType', 'requireAnc'];
    options.sort((a, b) {
      final c = b.count.compareTo(a.count);
      return c != 0 ? c : order.indexOf(a.key).compareTo(order.indexOf(b.key));
    });
    return options;
  }
}

class RelaxationSuggestion {
  const RelaxationSuggestion(this.key, this.preferences, this.count);
  final String key;
  final ProductPreferences preferences;
  final int count;
  String get label =>
      '${switch (key) {
        'budget' => '예산 제한 해제',
        'maxWeightGrams' => '최대 무게 제한 해제',
        'wearType' => '착용 형태 제한 해제',
        _ => 'ANC 필수 해제',
      }} · $count개 후보';
}
