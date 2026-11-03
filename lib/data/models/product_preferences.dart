import 'product.dart';

class ProductPreferences {
  const ProductPreferences({
    this.priorities = const [],
    this.budget,
    this.wearType,
    this.requireAnc = false,
    this.maxWeightGrams,
    this.weights = const {},
  });

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
  );

  Object? _spec(Product product, String key) {
    for (final spec in product.specs) {
      if (spec.key == key) return spec.value;
    }
    return null;
  }

  double? _number(Product product, String key) {
    final value = _spec(product, key);
    return value is num ? value.toDouble() : null;
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

  int? _waterLevel(Product product) {
    final value = _spec(product, 'waterResistance');
    if (value is! String) return null;
    final match = RegExp(r'^IP[0-6X]([0-9])$').firstMatch(value.toUpperCase());
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  double _score(Product product) {
    double total = 0;
    for (final priority in priorities.toSet()) {
      final batteryValue = product.earbudBattery?.value;
      final battery = batteryValue is num ? batteryValue.toDouble() : null;
      final weight = _number(product, 'weight');
      // 후보 수에 따라 점수가 바뀌지 않도록 사양별 고정 범위를 사용합니다.
      final value = switch (priority) {
        '배터리' => battery == null ? 0 : (battery / 12).clamp(0, 1).toDouble(),
        '무게' =>
          weight == null ? 0 : ((12 - weight) / 10).clamp(0, 1).toDouble(),
        'ANC' => _spec(product, 'anc') == true ? 1 : 0,
        '방수' => ((_waterLevel(product) ?? 0) / 8).clamp(0, 1).toDouble(),
        _ => 0,
      };
      total += value * weightFor(priority);
    }
    return total;
  }

  List<Product> recommend(List<Product> products) {
    final candidates = products.where(matches).toList();
    candidates.sort((a, b) {
      final score = _score(b).compareTo(_score(a));
      if (score != 0) return score;
      final price = a.price.compareTo(b.price);
      return price != 0 ? price : a.id.compareTo(b.id);
    });
    return candidates;
  }

  List<String> reasons(Product product) {
    final reasons = <String>[];
    if (budget != null) reasons.add('선택한 예산 범위에 들어요.');
    if (wearType != null) reasons.add('$wearType 제품이에요.');
    if (requireAnc) reasons.add('필수 조건인 ANC를 지원해요.');
    if (maxWeightGrams != null) {
      reasons.add('한 쪽 ${maxWeightGrams}g 이하 조건을 만족해요.');
    }
    if (priorities.contains('배터리')) {
      final battery = product.earbudBattery;
      if (battery != null) {
        reasons.add(
          '${battery.playbackCondition} 기준 최대 ${battery.value}시간이에요.',
        );
      }
    }
    if (priorities.contains('무게')) {
      final weight = _number(product, 'weight');
      if (weight != null) reasons.add('이어버드 한 쪽 무게는 ${weight}g이에요.');
    }
    if (priorities.contains('ANC') && _spec(product, 'anc') == true) {
      reasons.add('노이즈 캔슬링을 지원해요.');
    }
    if (priorities.contains('방수') && _waterLevel(product) != null) {
      reasons.add('방수 등급은 ${_spec(product, 'waterResistance')}예요.');
    }
    return reasons.isEmpty ? ['가격이 낮은 제품부터 살펴볼 수 있어요.'] : reasons;
  }

  List<String> comparisonInsights(List<Product> products) {
    final insights = <String>[];
    final ordered = priorities.toSet().toList()
      ..sort((a, b) => weightFor(b).compareTo(weightFor(a)));
    for (final priority in ordered) {
      if (priority == 'ANC') {
        final supported = products
            .where((p) => _spec(p, 'anc') == true)
            .map((p) => p.name)
            .join(', ');
        final unsupported = products
            .where((p) => _spec(p, 'anc') == false)
            .map((p) => p.name)
            .join(', ');
        if (supported.isNotEmpty || unsupported.isNotEmpty) {
          insights.add(
            'ANC: ${[if (supported.isNotEmpty) '$supported 지원', if (unsupported.isNotEmpty) '$unsupported 미지원'].join(', ')}.',
          );
        }
        final unknown = products
            .where((p) => _spec(p, 'anc') is! bool)
            .map((p) => p.name)
            .join(', ');
        if (unknown.isNotEmpty) insights.add('ANC: $unknown 지원 여부 정보가 없어요.');
        continue;
      }
      final missingBattery = products
          .where((p) => p.earbudBattery == null)
          .map((p) => p.name)
          .join(', ');
      if (priority == '배터리' && missingBattery.isNotEmpty) {
        insights.add('배터리: $missingBattery 정보가 없어 우열 판단에서 제외했어요.');
      }
      if (priority == '배터리' &&
          products
                  .where((p) => p.earbudBattery != null)
                  .map((p) => p.earbudBattery!.playbackCondition)
                  .toSet()
                  .length >
              1) {
        insights.add('배터리: 재생 조건이 달라 직접 우열을 정하지 않았어요.');
        continue;
      }
      double? value(Product p) => switch (priority) {
        '배터리' =>
          p.earbudBattery?.value is num
              ? (p.earbudBattery!.value as num).toDouble()
              : null,
        '무게' => _number(p, 'weight'),
        '방수' => _waterLevel(p)?.toDouble(),
        _ => null,
      };
      final known = products.where((p) => value(p) != null).toList()
        ..sort(
          (a, b) => priority == '무게'
              ? value(a)!.compareTo(value(b)!)
              : value(b)!.compareTo(value(a)!),
        );
      if (known.length >= 2 && value(known.first) != value(known.last)) {
        final best = known.first;
        final other = known.last;
        final difference = (value(best)! - value(other)!).abs();
        final amount = difference
            .toStringAsFixed(2)
            .replaceFirst(RegExp(r'\.?0+$'), '');
        insights.add(switch (priority) {
          '배터리' =>
            '배터리: ${best.name}이(가) ${other.name}보다 이어버드 재생 시간이 $amount시간 길어요 (${best.earbudBattery!.playbackCondition}).',
          '무게' =>
            '무게: ${best.name}이(가) ${other.name}보다 한 쪽 기준 ${amount}g 가벼워요.',
          _ =>
            '방수: ${best.name} ${_spec(best, 'waterResistance')}, ${other.name} ${_spec(other, 'waterResistance')}. 물 보호 등급의 마지막 숫자를 비교했어요.',
        });
      } else if (known.length == products.length && known.length > 1) {
        insights.add('$priority: 선택한 제품의 등록 수치가 같아요.');
      }
      final missing = products
          .where((p) => value(p) == null)
          .map((p) => p.name)
          .join(', ');
      if (missing.isNotEmpty && priority != '배터리') {
        insights.add('$priority: $missing 정보가 없어 우열 판단에서 제외했어요.');
      }
    }
    return insights;
  }
}
