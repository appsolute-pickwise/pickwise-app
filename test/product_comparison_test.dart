import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickwise/data/models/product.dart';
import 'package:pickwise/data/services/product_repository.dart';
import 'package:pickwise/presentation/providers/product_provider.dart';
import 'package:pickwise/presentation/screens/price_check_screen.dart';
import 'package:pickwise/presentation/screens/product_comparison_screen.dart';
import 'package:pickwise/presentation/screens/product_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeProductRepository extends ProductRepository {
  _FakeProductRepository(this.products);

  final List<Product> products;

  @override
  Future<List<Product>> loadProducts() async => products;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('좁은 화면에서 재생 조건이 다른 제품 3개를 구분해서 비교한다', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final products = await tester.runAsync(ProductRepository().loadProducts);
    final selected = [
      products!.singleWhere((product) => product.id == 'soundcore-p20i'),
      products.singleWhere((product) => product.id == 'soundcore-p41i'),
      products.singleWhere((product) => product.id == 'apple-airpods-4-anc'),
    ];
    final provider = ProductProvider(
      repository: _FakeProductRepository(selected),
    );
    addTearDown(provider.dispose);
    await provider.loadProducts();
    for (final product in selected) {
      provider.addToComparison(product.id);
    }
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: ProductComparisonScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('30시간'), findsOneWidget);
    expect(find.text('160시간'), findsOneWidget);
    expect(find.text('20시간'), findsOneWidget);
    expect(find.text('케이스 포함 · 일반 재생'), findsOneWidget);
    expect(find.text('케이스 포함 · ANC 켬'), findsNWidgets(2));
    expect(find.textContaining('시간 길어요.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('선택한 제품을 상세와 가격 확인 화면까지 전달한다', (tester) async {
    final product = Product(
      id: 'test-earbud',
      brand: '테스트 브랜드',
      name: '테스트 이어폰',
      category: 'earbuds',
      price: 100000,
      priceCheckedAt: DateTime(2026, 10, 28),
      priceComparisonSite: PriceComparisonSite.danawa,
      priceComparisonUrl: Uri.parse('https://example.com/product'),
      specs: const [
        ProductSpecification(key: 'wearType', label: '착용 형태', value: '커널형'),
      ],
    );
    final provider = ProductProvider(
      repository: _FakeProductRepository([product]),
    );
    addTearDown(provider.dispose);
    await provider.loadProducts();
    provider.addToComparison(product.id);

    await tester.pumpWidget(
      ChangeNotifierProvider<ProductProvider>.value(
        value: provider,
        child: const MaterialApp(home: ProductComparisonScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('테스트 이어폰'), findsOneWidget);
    expect(find.text('100,000원'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '테스트 이어폰 상세 정보 보기  →'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ProductDetailScreen>(find.byType(ProductDetailScreen))
          .product,
      same(product),
    );
    expect(find.text('100,000원'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '현재 가격은 다나와에서 보기  →'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<PriceCheckScreen>(find.byType(PriceCheckScreen)).product,
      same(product),
    );
    expect(find.text('가격 확인하기'), findsOneWidget);
    expect(find.text('다나와에서 가격 비교하기  ↗'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
