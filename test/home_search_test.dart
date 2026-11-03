import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickwise/data/models/product.dart';
import 'package:pickwise/data/services/product_repository.dart';
import 'package:pickwise/presentation/providers/product_provider.dart';
import 'package:pickwise/presentation/screens/home_screen.dart';
import 'package:pickwise/presentation/screens/search_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RetryRepository extends ProductRepository {
  int attempts = 0;

  @override
  Future<List<Product>> loadProducts() async {
    if (attempts++ == 0) throw const FormatException('제품 데이터 읽기 실패');
    return [];
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('가로 화면에서 키보드를 열어도 탐색 상단과 결과를 스크롤할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final provider = ProductProvider();
    addTearDown(provider.dispose);
    await tester.runAsync(provider.loadProducts);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Sony');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final scrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    await tester.drag(scrollable, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(0),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('홈에서 데이터 로딩 실패 후 다시 불러올 수 있다', (tester) async {
    final provider = ProductProvider(repository: _RetryRepository());
    addTearDown(provider.dispose);
    await provider.loadProducts();

    await tester.pumpWidget(
      ChangeNotifierProvider<ProductProvider>.value(
        value: provider,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    expect(find.text('제품 데이터 읽기 실패'), findsOneWidget);
    await tester.tap(find.text('다시 불러오기'));
    await tester.pumpAndSettle();

    expect(find.text('비교할 제품이 없습니다.'), findsOneWidget);
    expect(find.text('다시 불러오기'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('제품이 없을 때 검색어를 입력해도 빈 상태를 표시한다', (tester) async {
    final provider = ProductProvider();
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<ProductProvider>.value(
        value: provider,
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.enterText(find.byType(TextField), '없는 제품');
    await tester.pump();
    expect(find.text('찾는 상품이 없습니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
