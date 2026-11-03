import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickwise/data/models/product.dart';
import 'package:pickwise/data/models/product_preferences.dart';
import 'package:pickwise/data/services/product_repository.dart';
import 'package:pickwise/presentation/providers/product_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CatalogRepository extends ProductRepository {
  _CatalogRepository(this.products);
  final List<Product> products;

  @override
  Future<List<Product>> loadProducts() async => products;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('운영 JSON의 제품 ID와 가격 링크가 유효하고 임시 데이터가 없다', () async {
    final raw = jsonDecode(
      await rootBundle.loadString('assets/data/products.json'),
    ) as List;
    expect(raw.every((item) => item['isDummyData'] != true), isTrue);
    final products = await ProductRepository().loadProducts();
    expect(products, hasLength(3));
    expect(
      products.map((product) => product.id).toSet(),
      hasLength(products.length),
    );
    for (final product in products) {
      expect(product.price, greaterThan(0));
      expect(product.priceComparisonUrl.scheme, 'https');
      expect(product.priceComparisonUrl.host, isNotEmpty);
      expect(product.specs, isNotEmpty);
    }
  });

  test('비교 목록은 자동으로 채우지 않고 사용자의 선택을 복원한다', () async {
    final provider = ProductProvider();
    addTearDown(provider.dispose);
    await provider.loadProducts();
    expect(provider.selectedCount, 0);
    final product = provider.products.first;
    expect(provider.addToComparison(product.id), ProductSelectionResult.added);
    expect(
      provider.addToComparison(product.id),
      ProductSelectionResult.alreadySelected,
    );
    final restored = ProductProvider();
    addTearDown(restored.dispose);
    await restored.loadProducts();
    expect(restored.selectedProducts.single.id, product.id);
    restored.removeFromComparison(product.id);
    final cleared = ProductProvider();
    addTearDown(cleared.dispose);
    await cleared.loadProducts();
    expect(cleared.selectedCount, 0);
  });

  test('중복과 네 번째 비교 제품을 차단한다', () async {
    final products = await ProductRepository().loadProducts();
    final first = products.first;
    final fourth = Product(
      id: 'fourth-test-product',
      brand: first.brand,
      name: '추가 테스트 제품',
      category: first.category,
      price: first.price,
      priceCheckedAt: first.priceCheckedAt,
      priceComparisonSite: first.priceComparisonSite,
      priceComparisonUrl: first.priceComparisonUrl,
      specs: first.specs,
    );
    final provider = ProductProvider(
      repository: _CatalogRepository([...products, fourth]),
    );
    addTearDown(provider.dispose);
    await provider.loadProducts();
    for (final product in products) {
      expect(
        provider.addToComparison(product.id),
        ProductSelectionResult.added,
      );
    }
    expect(
      provider.addToComparison(first.id),
      ProductSelectionResult.alreadySelected,
    );
    expect(
      provider.addToComparison(fourth.id),
      ProductSelectionResult.maximumReached,
    );
    provider.removeFromComparison(first.id);
    expect(provider.addToComparison(fourth.id), ProductSelectionResult.added);
  });

  test('추천은 예산과 착용 형태를 만족하고 후보 추가로 두 제품의 순서가 바뀌지 않는다', () async {
    final products = await ProductRepository().loadProducts();
    const preferences = ProductPreferences(
      priorities: ['배터리', '무게'],
      budget: '15만원 초과',
      wearType: '커널형',
    );
    final ranked = preferences.recommend(products);
    expect(ranked, isNotEmpty);
    expect(ranked.every((product) => preferences.matches(product)), isTrue);
    final pair = ranked.take(2).toList().reversed.toList();
    expect(
      preferences.recommend(pair).map((product) => product.id),
      ranked.take(2).map((product) => product.id),
    );
  });
}
