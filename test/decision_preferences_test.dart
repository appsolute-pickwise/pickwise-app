import 'package:flutter_test/flutter_test.dart';
import 'package:pickwise/data/models/product_preferences.dart';
import 'package:pickwise/presentation/providers/product_provider.dart';

import 'fixtures/product_factory.dart';

void main() {
  test('중요도에 따라 순위가 바뀌며 후보 추가가 기존 쌍의 순서를 바꾸지 않는다', () {
    final long = product('긴 배터리', battery: 10, weight: 8);
    final light = product('가벼운 제품', battery: 5, weight: 3);
    const batteryFirst = ProductPreferences(
      priorities: ['배터리', '무게'],
      weights: {'배터리': 5, '무게': 1},
    );
    const weightFirst = ProductPreferences(
      priorities: ['배터리', '무게'],
      weights: {'배터리': 1, '무게': 5},
    );
    expect(batteryFirst.recommend([long, light]).first.id, long.id);
    expect(weightFirst.recommend([long, light]).first.id, light.id);
    final ranked = batteryFirst.recommend([long, light, product('다른 후보')]);
    expect(ranked.where((p) => p.id != '다른 후보').map((p) => p.id), [
      long.id,
      light.id,
    ]);
  });

  test('필수 ANC·무게 상한은 중요도보다 먼저 적용되고 미확인 값도 제외한다', () {
    final eligible = product('통과', weight: 6);
    final tooHeavy = product('초과', weight: 6.01, battery: 12);
    final unknownWeight = product('무게 없음', weight: null);
    final noAnc = product('ANC 없음', anc: false, normal: true);
    final unknownAnc = product('ANC 미확인', anc: null);
    const preferences = ProductPreferences(
      priorities: ['배터리'],
      weights: {'배터리': 5},
      requireAnc: true,
      maxWeightGrams: 6,
    );
    expect(
      preferences.recommend([
        eligible,
        tooHeavy,
        unknownWeight,
        noAnc,
        unknownAnc,
      ]),
      [eligible],
    );
    expect(preferences.exclusionReasons(unknownWeight), contains('무게 정보 없음'));
    expect(preferences.exclusionReasons(unknownAnc), contains('ANC 필수'));
    expect(
      preferences.emptyResultReasons([tooHeavy, unknownWeight, noAnc]).join(),
      contains('ANC 필수: 1개 제품 제외'),
    );
  });

  test('중요도는 필수 조건을 보존하고 허용 범위 밖 값은 제한한다', () {
    const initial = ProductPreferences(
      priorities: ['배터리'],
      budget: '5만~15만원',
      wearType: '커널형',
      requireAnc: true,
      maxWeightGrams: 6,
    );
    final changed = initial.withWeights({'배터리': 99, '무게': -10});
    expect(changed.requireAnc, isTrue);
    expect(changed.maxWeightGrams, 6);
    expect(changed.budget, initial.budget);
    expect(changed.wearType, initial.wearType);
    expect(changed.weightFor('배터리'), 5);
    expect(changed.weightFor('무게'), 1);
  });

  test('맞춤 비교는 배터리 장점과 무게에서 포기할 점을 모델별로 설명한다', () {
    const preferences = ProductPreferences(
      priorities: ['배터리', '무게'],
      weights: {'배터리': 5, '무게': 2},
    );
    final insights = preferences.comparisonInsights([
      product('긴 배터리', battery: 10, weight: 8),
      product('가벼운 제품', battery: 5, weight: 3),
    ]);
    expect(insights.first, contains('긴 배터리이(가) 가벼운 제품보다'));
    expect(insights.first, contains('5시간 길어요'));
    expect(insights.last, contains('가벼운 제품이(가) 긴 배터리보다'));
    expect(insights.last, contains('5g 가벼워요'));
  });

  test('재생 조건 차이와 누락 사양을 유리한 성능으로 꾸미지 않는다', () {
    const preferences = ProductPreferences(priorities: ['배터리', '무게', 'ANC']);
    final insights = preferences.comparisonInsights([
      product('ANC 모델'),
      product('일반 모델', normal: true, anc: false, weight: null),
      product('정보 없는 모델', anc: null, weight: null),
    ]).join();
    expect(insights, contains('재생 조건이 달라'));
    expect(insights, isNot(contains('시간 길어요')));
    expect(insights, contains('무게: 일반 모델, 정보 없는 모델 정보가 없어'));
    expect(insights, contains('정보 없는 모델 지원 여부 정보가 없어요'));
  });

  test('공통 Provider에 전달한 기준은 원본 리스트·맵 변경에 영향받지 않는다', () {
    final provider = ProductProvider();
    addTearDown(provider.dispose);
    final priorities = ['배터리'];
    final weights = {'배터리': 4};
    provider.updateSelectionPreferences(
      ProductPreferences(
        priorities: priorities,
        weights: weights,
        requireAnc: true,
      ),
    );
    priorities.clear();
    weights['배터리'] = 1;
    expect(provider.selectionPreferences.priorities, ['배터리']);
    expect(provider.selectionPreferences.weightFor('배터리'), 4);
    expect(provider.selectionPreferences.requireAnc, isTrue);
  });
}
