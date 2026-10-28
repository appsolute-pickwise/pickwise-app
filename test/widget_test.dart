import 'package:flutter_test/flutter_test.dart';
import 'package:pickwise/data/models/product.dart';
import 'package:pickwise/data/services/product_repository.dart';
import 'package:pickwise/main.dart';
import 'package:pickwise/presentation/providers/product_provider.dart';
import 'package:provider/provider.dart';

class _FakeProductRepository extends ProductRepository {
  _FakeProductRepository(this.products);

  final List<Product> products;

  @override
  Future<List<Product>> loadProducts() async => products;
}

void main() {
  testWidgets('제품 비교에서 선택한 제품의 상세 화면을 연다', (tester) async {
    final product = Product(
      id: 'test-earbud',
      brand: '테스트 브랜드',
      name: '테스트 이어폰',
      category: 'earbuds',
      price: 100000,
      priceCheckedAt: DateTime(2026, 10, 28),
      priceComparisonSite: PriceComparisonSite.danawa,
      priceComparisonUrl: Uri.parse('https://example.com'),
      specs: const [
        ProductSpecification(key: 'wearType', label: '착용 형태', value: '커널형'),
      ],
    );
    final provider = ProductProvider(
      repository: _FakeProductRepository([product]),
    );
    await provider.loadProducts();

    await tester.pumpWidget(
      ChangeNotifierProvider<ProductProvider>.value(
        value: provider,
        child: const PickWiseApp(),
      ),
    );

    expect(find.text('제품 비교'), findsOneWidget);
    expect(find.text('테스트 이어폰'), findsOneWidget);
    expect(find.text('100,000원'), findsOneWidget);
    expect(find.text('배터리¹'), findsOneWidget);
    expect(find.text('방수 등급'), findsOneWidget);

    await tester.tap(find.textContaining('상세 정보 확인하기'));
    await tester.pumpAndSettle();

    expect(find.text('제품 상세'), findsOneWidget);
    expect(find.text('알아두면 좋은 점'), findsOneWidget);
    expect(find.text('100,000원'), findsOneWidget);
    expect(find.textContaining('네이버 쇼핑에서 보기'), findsOneWidget);
  });
}
