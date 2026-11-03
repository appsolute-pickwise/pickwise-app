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
  final provider = ProductProvider();
  addTearDown(provider.dispose);
  await tester.runAsync(provider.loadProducts);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(value: provider, child: const PickWiseApp()),
  );
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
  testWidgets('바가 숨은 뒤 빈 검색 결과로 바뀌면 키보드를 닫고 탭을 사용할 수 있다', (tester) async {
    await _openApp(tester);
    await tester.tap(find.text('탐색'));
    await tester.pumpAndSettle();
    await tester.drag(_searchList(), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(_bar)).height, 0);
    tester.state<ScrollableState>(_searchList()).position.jumpTo(0);
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.enterText(find.byType(TextField), '존재하지 않는 제품');
    await tester.pumpAndSettle();
    expect(find.text('찾는 상품이 없습니다.'), findsOneWidget);
    expect(tester.getSize(find.byKey(_bar)).height, 0);
    FocusManager.instance.primaryFocus?.unfocus();
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(_bar)).height, 64);
    await tester.tap(find.text('비교'));
    await tester.pumpAndSettle();
    expect(find.text('제품 비교'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('스크롤할 수 없는 높이로 바뀌면 하단 바를 복원한다', (tester) async {
    await _openApp(tester);
    await tester.tap(find.text('탐색'));
    await tester.pumpAndSettle();
    await tester.drag(_searchList(), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(_bar)).height, 0);
    tester.view.physicalSize = const Size(390, 10000);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(_bar)).height, 64);
    expect(tester.takeException(), isNull);
  });

  testWidgets('아래로 읽으면 바가 숨고 위로 스크롤하면 다시 나타난다', (tester) async {
    await _openApp(tester);
    await tester.tap(find.text('탐색'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(_bar)).height, 64);
    await tester.drag(_searchList(), const Offset(0, -300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getSize(find.byKey(_bar)).height, inExclusiveRange(0, 64));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(_bar)).height, 0);
    await tester.drag(_searchList(), const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(_bar)).height, 64);
    expect(tester.takeException(), isNull);
  });

  testWidgets('바가 숨은 상태에서 제품을 담으면 비교 탭을 다시 사용할 수 있다', (tester) async {
    final provider = await _openApp(tester);
    await tester.tap(find.text('탐색'));
    await tester.pumpAndSettle();
    await tester.drag(_searchList(), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(_bar)).height, 0);
    provider.addToComparison(provider.products.first.id);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(_bar)).height, 64);
    await tester.tap(find.text('비교'));
    await tester.pumpAndSettle();
    expect(find.text('제품 비교'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('탭 전환 뒤에도 검색어와 목록 위치가 유지된다', (tester) async {
    await _openApp(tester);
    await tester.tap(find.text('탐색'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Sony');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final position = tester.state<ScrollableState>(_searchList()).position;
    position.jumpTo(80);
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
    expect(tester.takeException(), isNull);
  });

  testWidgets('가로 제품 스크롤은 하단 바를 숨기지 않는다', (tester) async {
    await _openApp(tester);
    final horizontalList = find.byWidgetPredicate(
      (widget) =>
          widget is ListView && widget.scrollDirection == Axis.horizontal,
    );
    final horizontal = find
        .descendant(of: horizontalList, matching: find.byType(Scrollable))
        .first;
    await tester.ensureVisible(horizontal);
    await tester.pumpAndSettle();
    await tester.drag(horizontal, const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(_bar)).height, 64);
    expect(tester.takeException(), isNull);
  });

  testWidgets('검색 키보드를 열면 바가 숨고 닫으면 복원된다', (tester) async {
    await _openApp(tester);
    await tester.tap(find.text('탐색'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(_bar)).height, 0);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(_bar)).height, 64);
    expect(tester.takeException(), isNull);
  });

  testWidgets('접근성 탐색에서는 스크롤해도 바를 유지하고 모션 감소를 반영한다', (tester) async {
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
    expect(tester.getSize(find.byKey(_bar)).height, 64);
    expect(
      tester
          .widget<NavigationBar>(find.byType(NavigationBar))
          .animationDuration,
      Duration.zero,
    );
    expect(tester.takeException(), isNull);
  });
}
