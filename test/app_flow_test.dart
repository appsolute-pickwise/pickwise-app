import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickwise/data/services/product_repository.dart';
import 'package:pickwise/main.dart';
import 'package:pickwise/presentation/providers/product_provider.dart';
import 'package:pickwise/presentation/screens/product_detail_screen.dart';
import 'package:pickwise/presentation/screens/result_screen.dart';
import 'package:pickwise/presentation/screens/search_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProductProvider> _openApp(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final provider = ProductProvider(repository: ProductRepository());
  addTearDown(provider.dispose);
  await tester.runAsync(provider.loadProducts);
  expect(provider.hasLoadError, isFalse);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(value: provider, child: const PickWiseApp()),
  );
  await tester.pumpAndSettle();
  return provider;
}

void main() {
  testWidgets('작은 화면에서 키보드를 열고 검색 결과 없음 상태를 표시한다', (tester) async {
    await _openApp(tester, size: const Size(320, 640));
    await tester.tap(find.text('탐색'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetViewInsets);
    await tester.enterText(find.byType(TextField), '존재하지 않는 제품');
    await tester.pumpAndSettle();
    expect(find.text('찾는 상품이 없습니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('예산에 맞는 제품이 없으면 기준 선택 화면으로 돌아갈 수 있다', (tester) async {
    await _openApp(tester);
    await tester.ensureVisible(find.text('기준 선택하기 →'));
    await tester.tap(find.text('기준 선택하기 →'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('5만원 미만'));
    await tester.tap(find.text('5만원 미만'));
    await tester.pump();
    await tester.ensureVisible(find.text('귀걸이형'));
    await tester.tap(find.text('귀걸이형'));
    await tester.pump();
    await tester.tap(find.text('추천 보기'));
    await tester.pumpAndSettle();
    expect(find.text('조건에 맞는 제품이 없습니다.'), findsOneWidget);
    await tester.tap(find.text('기준 다시 고르기'));
    await tester.pumpAndSettle();
    expect(find.text('내 기준 고르기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('탐색에서 최대 3개를 담고 세 번째 제품 상세에서 홈으로 돌아온다', (tester) async {
    final provider = await _openApp(tester);
    expect(provider.selectedCount, 0);
    await tester.tap(find.text('탐색'));
    await tester.pumpAndSettle();
    final scrollable = find
        .descendant(
          of: find.byType(SearchScreen),
          matching: find.byType(Scrollable),
        )
        .last;
    for (final product in provider.products.take(3)) {
      final button = find.byKey(ValueKey('compare-${product.id}'));
      await tester.scrollUntilVisible(button, 150, scrollable: scrollable);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }
    expect(provider.selectedCount, 3);
    await tester.tap(find.text('비교'));
    await tester.pumpAndSettle();
    expect(find.text('제품 비교'), findsOneWidget);
    await tester.tap(find.text('상세 보기').at(2));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ProductDetailScreen>(find.byType(ProductDetailScreen))
          .product
          .id,
      provider.products[2].id,
    );
    await tester.tap(find.text('홈'));
    await tester.pumpAndSettle();
    expect(find.text('내게 맞는\n선택을 쉽게.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('홈에서 선택한 예산이 추천 결과에 반영된다', (tester) async {
    final provider = await _openApp(tester);
    final start = find.text('기준 선택하기 →');
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    await tester.tap(find.text('배터리'));
    await tester.ensureVisible(find.text('15만원 초과'));
    await tester.tap(find.text('15만원 초과'));
    await tester.pump();
    await tester.tap(find.text('추천 보기'));
    await tester.pumpAndSettle();
    final screen = tester.widget<ResultScreen>(find.byType(ResultScreen));
    final candidates = screen.preferences.recommend(provider.products);
    expect(candidates, isNotEmpty);
    expect(candidates.every((product) => product.price > 150000), isTrue);
    expect(screen.preferences.priorities, contains('배터리'));
    final first = candidates.first;
    final button = find.byKey(ValueKey('compare-${first.id}'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(provider.isSelected(first.id), isTrue);
    final compare = find.text('선택한 1개 제품 비교하기');
    await tester.scrollUntilVisible(
      compare,
      150,
      scrollable: find
          .descendant(
            of: find.byType(ResultScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(compare);
    await tester.pumpAndSettle();
    expect(find.text('제품 비교'), findsOneWidget);
    expect(find.text(first.name), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
