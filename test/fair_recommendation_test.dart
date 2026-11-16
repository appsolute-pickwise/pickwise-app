import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pickwise/data/models/product.dart';
import 'package:pickwise/data/models/product_preferences.dart';
import 'package:pickwise/data/services/product_repository.dart';
import 'package:pickwise/presentation/providers/product_provider.dart';
import 'package:pickwise/presentation/screens/result_screen.dart';
import 'package:pickwise/presentation/screens/product_comparison_screen.dart';
import 'package:pickwise/presentation/widgets/product_list_tile.dart';

import 'fixtures/product_factory.dart';

class Catalog extends ProductRepository {
  Catalog(this.items);
  final List<Product> items;
  @override
  Future<List<Product>> loadProducts() async => items;
}

Future<ProductProvider> show(
  WidgetTester tester,
  Widget screen,
  List<Product> items,
) async {
  final p = ProductProvider(repository: Catalog(items));
  addTearDown(p.dispose);
  await p.loadProducts();
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: p,
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
  return p;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('다른 재생 조건·누락값은 참고 후보이며 ANC·방수는 점수화하지 않는다', () {
    final anc = product('anc', battery: 6),
        normal = product('normal', battery: 12, normal: true),
        missing = product('missing', weight: null);
    const p = ProductPreferences(priorities: ['배터리', '무게']);
    expect(p.recommend([anc, normal, missing]), [anc]);
    expect(p.referenceCandidates([anc, normal, missing]), [missing, normal]);
    expect(p.score(missing), isNull);
    expect(p.withBatteryCondition('normal').recommend([anc, normal]), [normal]);
    const info = ProductPreferences(priorities: ['ANC']);
    final unsupported = product('no', anc: false, price: 50000);
    expect(info.recommend([anc, unsupported]).first, unsupported);
    expect(info.score(anc), isNull);
    expect(info.score(unsupported), isNull);
    expect(ProductPreferences.fromJson(p.toJson()).batteryCondition, 'ancOn');
  });
  test('한 조건만 완화하며 실제 후보 수 내림차순·동률 고정 순서로 제안한다', () {
    final items = [
      product('비싼 후보', price: 200000),
      product('싼 후보', price: 30000, anc: false),
    ];
    const p = ProductPreferences(budget: '5만원 미만', requireAnc: true);
    expect(items.where(p.matches), isEmpty);
    final options = p.relaxations(items);
    expect(options.map((o) => o.key), ['budget', 'requireAnc']);
    expect(options.map((o) => o.count), [1, 1]);
    expect(options.first.preferences.requireAnc, isTrue);
    expect(options.last.preferences.budget, p.budget);
    expect(p.budget, '5만원 미만');
  });
  testWidgets('후보는 3개씩 더 보며 조건 완화는 적용·되돌리기로만 변경한다', (tester) async {
    await show(
      tester,
      const ResultScreen(),
      List.generate(7, (i) => product('p$i')),
    );
    expect(find.byType(ProductListTile), findsNWidgets(3));
    await tester.ensureVisible(find.text('순위 후보 더 보기'));
    await tester.tap(find.text('순위 후보 더 보기'));
    await tester.pumpAndSettle();
    expect(find.byType(ProductListTile), findsNWidgets(6));
    await tester.pumpWidget(const SizedBox());
    await show(
      tester,
      const ResultScreen(preferences: ProductPreferences(budget: '5만원 미만')),
      [product('비싼 제품')],
    );
    expect(find.text('조건에 맞는 제품이 없습니다.'), findsOneWidget);
    await tester.tap(find.text('예산 제한 해제 · 1개 후보'));
    await tester.pumpAndSettle();
    expect(find.byType(ProductListTile), findsOneWidget);
    await tester.ensureVisible(find.text('조건 완화 되돌리기'));
    await tester.tap(find.text('조건 완화 되돌리기'));
    await tester.pumpAndSettle();
    expect(find.text('조건에 맞는 제품이 없습니다.'), findsOneWidget);
  });
  testWidgets('가격은 먼저, 선택 기준만 우선 표시하고 전체 사양을 펼친다', (tester) async {
    final p = await show(tester, const ProductComparisonScreen(), [
      product('test'),
    ]);
    p.addToComparison('test');
    p.updateSelectionPreferences(const ProductPreferences(priorities: ['무게']));
    await tester.pumpAndSettle();
    expect(find.text('배터리'), findsNothing);
    expect(find.text('무게'), findsOneWidget);
    expect(find.text('가격'), findsOneWidget);
    await tester.ensureVisible(find.text('전체 사양 보기'));
    await tester.tap(find.text('전체 사양 보기'));
    await tester.pumpAndSettle();
    expect(find.text('배터리'), findsOneWidget);
    expect(find.textContaining('상세 정보 보기  →'), findsNothing);
    expect(find.text('상세 보기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
