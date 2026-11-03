import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickwise/data/models/product.dart';
import 'package:pickwise/data/models/product_preferences.dart';
import 'package:pickwise/data/services/product_repository.dart';
import 'package:pickwise/main.dart';
import 'package:pickwise/presentation/providers/product_provider.dart';
import 'package:pickwise/presentation/screens/result_screen.dart';
import 'package:pickwise/presentation/screens/product_comparison_screen.dart';
import 'package:pickwise/presentation/widgets/product_list_tile.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/product_factory.dart' as fixtures;

class _ProductsRepository extends ProductRepository {
  _ProductsRepository(this.products);
  final List<Product> products;

  @override
  Future<List<Product>> loadProducts() async => products;
}

Future<ProductProvider> _openApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(320, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final provider = ProductProvider();
  addTearDown(provider.dispose);
  await tester.runAsync(provider.loadProducts);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(value: provider, child: const PickWiseApp()),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('기준 선택하기 →'));
  await tester.tap(find.text('기준 선택하기 →'));
  await tester.pumpAndSettle();
  return provider;
}

void main() {
  testWidgets('추천에서 바꾼 중요도는 기준 화면으로 돌아와도 유지된다', (tester) async {
    final provider = await _openApp(tester);
    await tester.tap(find.text('배터리'));
    await tester.pump();
    await tester.tap(find.text('추천 보기'));
    await tester.pumpAndSettle();
    final slider = find.byKey(const ValueKey('weight-배터리'));
    await tester.ensureVisible(slider);
    await tester.tapAt(tester.getTopRight(slider) + const Offset(-24, 24));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(provider.selectionPreferences.weightFor('배터리'), 5);
    expect(find.text('배터리 중요도 5 / 5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('기존 비교 제품 한 개도 새 필수 조건 불일치를 알린다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final product = fixtures.product('기존 제품', anc: false, normal: true);
    final provider = ProductProvider(
      repository: _ProductsRepository([product]),
    );
    addTearDown(provider.dispose);
    await provider.loadProducts();
    provider.addToComparison(product.id);
    provider.updateSelectionPreferences(
      const ProductPreferences(requireAnc: true),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: ProductComparisonScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('현재 필수·선택 조건과 달라요 (ANC 필수)'), findsOneWidget);
    expect(provider.selectedCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320px와 확대 글자에서 필수 조건·중요도를 설정할 수 있다', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _openApp(tester);
    await tester.tap(find.text('배터리'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('weight-배터리')));
    await tester.pumpAndSettle();
    expect(find.text('배터리 중요도 3 / 5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A의 홈에서 B의 필수 조건을 선택하고 C의 맞춤 비교로 전달한다', (tester) async {
    final provider = await _openApp(tester);
    await tester.tap(find.text('배터리'));
    await tester.tap(find.text('무게'));
    await tester.pump();
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(DropdownButtonFormField<double>));
    await tester.tap(find.byType(DropdownButtonFormField<double>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('6g 이하').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('추천 보기'));
    await tester.pumpAndSettle();
    final preferences = provider.selectionPreferences;
    expect(preferences.requireAnc, isTrue);
    expect(preferences.maxWeightGrams, 6);
    final candidates = preferences.recommend(provider.products);
    expect(candidates, isNotEmpty);
    expect(candidates.every((p) => preferences.matches(p)), isTrue);
    for (final product in candidates.take(2)) {
      final button = find.byKey(ValueKey('compare-${product.id}'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }
    final compare = find.text('선택한 2개 제품 비교하기');
    await tester.ensureVisible(compare);
    await tester.tap(compare);
    await tester.pumpAndSettle();
    expect(find.text('내 기준으로 본 차이'), findsOneWidget);
    expect(find.text('배터리 3/5 · 무게 3/5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('중요도 조절은 즉시 순위·이유를 바꾸고 필수 조건을 보존한다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final long = fixtures.product('긴 배터리', battery: 10, weight: 8);
    final light = fixtures.product('가벼운 제품', battery: 5, weight: 3);
    final provider = ProductProvider(
      repository: _ProductsRepository([long, light]),
    );
    addTearDown(provider.dispose);
    await provider.loadProducts();
    const preferences = ProductPreferences(
      priorities: ['배터리', '무게'],
      requireAnc: true,
      weights: {'배터리': 5, '무게': 1},
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: ResultScreen(preferences: preferences)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<ProductListTile>(find.byType(ProductListTile))
          .first
          .product
          .id,
      long.id,
    );
    final batterySlider = find.byKey(const ValueKey('weight-배터리'));
    await tester.ensureVisible(batterySlider);
    await tester.tapAt(tester.getTopLeft(batterySlider) + const Offset(24, 24));
    await tester.pumpAndSettle();
    final weightSlider = find.byKey(const ValueKey('weight-무게'));
    await tester.ensureVisible(weightSlider);
    await tester.tapAt(
      tester.getTopRight(weightSlider) + const Offset(-24, 24),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<ProductListTile>(find.byType(ProductListTile))
          .first
          .product
          .id,
      light.id,
    );
    expect(find.byKey(const ValueKey('ranking-change')), findsOneWidget);
    expect(provider.selectionPreferences.requireAnc, isTrue);
    expect(provider.selectionPreferences.weightFor('무게'), 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('일치 제품이 없으면 제외 원인을 표시하고 조건 화면으로 돌아온다', (tester) async {
    await _openApp(tester);
    await tester.ensureVisible(find.text('5만원 미만'));
    await tester.tap(find.text('5만원 미만'));
    await tester.ensureVisible(find.text('귀걸이형'));
    await tester.tap(find.text('귀걸이형'));
    await tester.pump();
    await tester.tap(find.text('추천 보기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('착용 형태:'), findsOneWidget);
    expect(find.textContaining('예산 범위:'), findsOneWidget);
    await tester.tap(find.text('기준 다시 고르기'));
    await tester.pumpAndSettle();
    expect(find.text('✓ 귀걸이형'), findsOneWidget);
    expect(find.text('✓ 5만원 미만'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
