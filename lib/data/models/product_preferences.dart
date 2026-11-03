import 'product.dart';

class ProductPreferences {
  const ProductPreferences({
    this.priorities = const [],
    this.budget,
    this.wearType,
  });

  final List<String> priorities;
  final String? budget;
  final String? wearType;

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

  bool matches(Product product) {
    final inBudget = switch (budget) {
      '5만원 미만' => product.price < 50000,
      '5만~15만원' => product.price >= 50000 && product.price <= 150000,
      '15만원 초과' => product.price > 150000,
      _ => true,
    };
    return inBudget &&
        (wearType == null || _spec(product, 'wearType') == wearType);
  }

  int? _waterLevel(Product product) {
    final value = _spec(product, 'waterResistance');
    if (value is! String) return null;
    final match = RegExp(r'^IP[0-6X]([0-9])$').firstMatch(value.toUpperCase());
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  double _score(Product product) {
    double total = 0;
    for (final priority in priorities) {
      final battery = _number(product, 'batteryHoursAncOn');
      final weight = _number(product, 'weight');
      // 후보 수에 따라 점수가 바뀌지 않도록 사양별 고정 범위를 사용합니다.
      total += switch (priority) {
        '배터리' => battery == null ? 0 : (battery / 12).clamp(0, 1).toDouble(),
        '무게' =>
          weight == null ? 0 : ((12 - weight) / 10).clamp(0, 1).toDouble(),
        'ANC' => _spec(product, 'anc') == true ? 1 : 0,
        '방수' => ((_waterLevel(product) ?? 0) / 8).clamp(0, 1).toDouble(),
        _ => 0,
      };
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
    if (priorities.contains('배터리')) {
      final hours = _number(product, 'batteryHoursAncOn');
      if (hours != null) reasons.add('ANC를 켰을 때 재생 시간은 $hours시간이에요.');
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
}
