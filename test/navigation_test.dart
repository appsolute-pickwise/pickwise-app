import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pickwise/data/services/product_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickwise/main.dart';
import 'package:pickwise/presentation/providers/product_provider.dart';
import 'package:pickwise/presentation/screens/search_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _bar = ValueKey('app-bottom-navigation');

Future<ProductProvider> _openApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final provider = ProductProvider(repository: AssetProductRepository());
  addTearDown(provider.dispose);
  await tester.runAsync(provider.loadProducts);
  FlutterSecureStorage.setMockInitialValues({});
  await tester.pumpWidget(
    ChangeNotifierProvider.value(value: provider, child: const PickWiseApp()),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('로그인 없이 둘러보기'));
  await tester.pumpAndSettle();
  return provider;
}

Finder _searchList() => find
    .descendant(
      of: find.byType(SearchScreen),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    )
    .last;

void main() {
  testWidgets('아래·위 스크롤에도 바는 고정되고 구분선만 반응한다', (tester) async {
    await _openApp(tester);
    await tester.tap(find.text('탐색'));
    await tester.pumpAndSettle();
    final before = tester.getRect(find.byKey(_bar));
    BorderStyle border() =>
        ((tester
                            .widget<AnimatedContainer>(
                              find.byKey(
                                const ValueKey('bottom-navigation-surface'),
                              ),
                            )
                            .foregroundDecoration!
                        as BoxDecoration)
                    .border!
                as Border)
            .top
            .style;
    expect(border(), BorderStyle.none);
    await tester.drag(_searchList(), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(_bar)), before);
    expect(border(), BorderStyle.solid);
    tester.state<ScrollableState>(_searchList()).position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(border(), BorderStyle.none);
    expect(tester.getSize(find.byKey(_bar)).height, 56);
  });
  testWidgets('빈 검색 결과와 화면 크기 변경에도 탭 이동을 유지한다', (tester) async {
    await _openApp(tester);
    await tester.tap(find.text('탐색'));
    await tester.pumpAndSettle();
    await tester.drag(_searchList(), const Offset(0, -300));
    await tester.pumpAndSettle();
    tester.state<ScrollableState>(_searchList()).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '존재하지 않는 제품');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(find.text('찾는 상품이 없습니다.'), findsOneWidget);
    expect(tester.getSize(find.byKey(_bar)).height, 56);
    tester.view.physicalSize = const Size(390, 10000);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(_bar)).height, 56);
    await tester.tap(find.text('비교'));
    await tester.pumpAndSettle();
    expect(find.text('제품 비교'), findsOneWidget);
  });
  testWidgets('스크롤한 위치에서 제품을 담고 바로 비교 탭으로 이동한다', (tester) async {
    final provider = await _openApp(tester);
    await tester.tap(find.text('탐색'));
    await tester.pumpAndSettle();
    await tester.drag(_searchList(), const Offset(0, -300));
    await tester.pumpAndSettle();
    provider.addToComparison(provider.products.first.id);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(_bar)).height, 56);
    await tester.tap(find.text('비교'));
    await tester.pumpAndSettle();
    expect(find.text('제품 비교'), findsOneWidget);
  });
  testWidgets('탭 전환 뒤에도 검색어와 목록 위치가 유지된다', (tester) async {
    await _openApp(tester);
    await tester.tap(find.text('탐색'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Sony');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    tester.state<ScrollableState>(_searchList()).position.jumpTo(80);
    await tester.pumpAndSettle();
    await tester.tap(find.text('비교'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('탐색'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'Sony',
    );
    expect(tester.state<ScrollableState>(_searchList()).position.pixels, 80);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
  });
  testWidgets('가로 제품 스크롤은 바의 위치와 크기를 바꾸지 않는다', (tester) async {
    await _openApp(tester);
    final horizontal = find
        .descendant(
          of: find.byKey(const ValueKey('home-product-carousel')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.ensureVisible(horizontal);
    await tester.pumpAndSettle();
    final before = tester.getRect(find.byKey(_bar));
    await tester.drag(horizontal, const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(horizontal).position.pixels,
      greaterThan(0),
    );
    expect(tester.getRect(find.byKey(_bar)), before);
  });
  testWidgets('키보드 입력 중에만 바를 숨기고 닫으면 같은 크기로 돌아온다', (tester) async {
    await _openApp(tester);
    await tester.tap(find.text('탐색'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(_bar)).height, 0);
    expect(find.byType(NavigationDestination), findsNothing);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(_bar)).height, 56);
  });
  testWidgets('동작 줄이기를 켜면 표시 애니메이션을 생략한다', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
          accessibleNavigation: true,
          disableAnimations: true,
        );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _openApp(tester);
    await tester.tap(find.text('탐색'));
    await tester.pumpAndSettle();
    await tester.drag(_searchList(), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(_bar)).height, 56);
    expect(
      tester
          .widget<NavigationBar>(find.byType(NavigationBar))
          .animationDuration,
      Duration.zero,
    );
  });
  for (final inset in [0.0, 16.0, 24.0, 34.0]) {
    testWidgets('안전영역 $inset px는 하단에 한 번만 적용한다', (tester) async {
      tester.view.padding = FakeViewPadding(bottom: inset);
      tester.view.viewPadding = FakeViewPadding(bottom: inset);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      await _openApp(tester);
      final bar = tester.getRect(find.byKey(_bar));
      expect(bar.height, 56 + inset);
      expect(bar.bottom, 844);
      for (final element in find.byType(NavigationDestination).evaluate()) {
        final rect = tester.getRect(find.byWidget(element.widget));
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(rect.bottom, lessThanOrEqualTo(844 - inset));
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('작은 폭과 큰 글자에서는 높이를 늘려 탭을 읽을 수 있다', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _openApp(tester);
    tester.view.physicalSize = const Size(320, 844);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(_bar)).height, 67);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });
  testWidgets('가로 화면에서는 좌우 안전영역을 지키며 네 탭을 유지한다', (tester) async {
    await _openApp(tester);
    tester.view.physicalSize = const Size(844, 390);
    tester.view.padding = const FakeViewPadding(
      left: 44,
      right: 44,
      bottom: 21,
    );
    tester.view.viewPadding = const FakeViewPadding(
      left: 44,
      right: 44,
      bottom: 21,
    );
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(_bar)).height, 77);
    final first = tester.getRect(find.byType(NavigationDestination).first),
        last = tester.getRect(find.byType(NavigationDestination).last);
    expect(first.left, greaterThanOrEqualTo(44));
    expect(last.right, lessThanOrEqualTo(800));
    await tester.tap(find.text('마이'));
    await tester.pumpAndSettle();
    expect(find.text('마이페이지'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
