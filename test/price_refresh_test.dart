import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pickwise/data/models/product.dart';
import 'package:pickwise/data/services/pickwise_api.dart';
import 'package:pickwise/data/services/product_repository.dart';
import 'package:pickwise/presentation/providers/product_provider.dart';
import 'package:pickwise/presentation/screens/price_check_screen.dart';
import 'package:pickwise/presentation/widgets/product_formatters.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Map<String, dynamic> row() => Map<String, dynamic>.from(
    (jsonDecode(
          File('assets/data/products.json').readAsStringSync(),
        ) as List).first
        as Map,
  );

  test('기존 수동 가격과 자동 조회 실패의 마지막 확인 시각을 구분한다', () {
    final json = row();
    expect(formatPriceFreshness(Product.fromJson(json)), contains('수동 확인'));
    json['priceFetchedAt'] = '2026-11-16T01:27:00Z';
    json['priceRefreshStatus'] = 'failed';
    final label = formatPriceFreshness(Product.fromJson(json));
    expect(label, contains('조회'));
    expect(label, contains('갱신 지연'));
    expect(label, isNot(contains('수동 확인')));
  });

  testWidgets('열린 가격 화면은 새 가격을 표시하고 비교 선택은 유지한다', (tester) async {
    final json = row();
    final api = PickwiseApi(
      baseUrl: 'https://price-test.invalid',
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'items': [json],
              'total': 1,
            }),
          ),
          200,
        ),
      ),
    );
    final provider = ProductProvider(repository: ProductRepository(api: api));
    addTearDown(provider.dispose);
    addTearDown(api.client.close);
    await provider.loadProducts();
    final original = provider.products.single;
    provider.addToComparison(original.id);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(home: PriceCheckScreen(product: original)),
      ),
    );
    json['price'] = 222222;
    json['priceFetchedAt'] = '2026-11-16T01:27:00Z';
    json['priceRefreshStatus'] = 'updated';
    await provider.loadProducts();
    await tester.pump();
    expect(find.text('222,222원'), findsOneWidget);
    expect(find.textContaining('다나와 조회 가격'), findsOneWidget);
    expect(provider.selectedProducts.single.id, original.id);
    expect(provider.selectedProducts.single.price, 222222);
    expect(tester.takeException(), isNull);
  });
}
