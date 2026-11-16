import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pickwise/data/services/pickwise_api.dart';
import 'package:pickwise/data/services/product_repository.dart';
import 'package:pickwise/presentation/providers/product_provider.dart';
import 'package:pickwise/presentation/providers/session_provider.dart';
import 'package:pickwise/presentation/screens/comparison_history_screen.dart';

import 'fixtures/session_storage.dart';

void main() {
  testWidgets('저장 당시·현재 가격과 기존 기록을 구분하고 다시 비교해도 원본을 수정하지 않는다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final raw =
        (jsonDecode(
              File('assets/data/products.json').readAsStringSync(),
            ) as List).first
            as Map<String, dynamic>;
    final original = {...raw, 'price': 90000};
    final current = {...raw, 'price': 100000};
    var writes = 0;
    final api = PickwiseApi(
      baseUrl: 'https://test.invalid',
      client: MockClient((r) async {
        Object body;
        if (r.url.path.endsWith('/login')) {
          body = {'accessToken': 'access', 'refreshToken': 'refresh'};
        } else if (r.url.path.endsWith('/auth/me')) {
          body = {'id': 'a', 'email': 'a@example.test'};
        } else if (r.url.path.endsWith('/preferences')) {
          body = {'preferences': {}};
        } else if (r.url.path.contains('/products')) {
          body = {
            'items': [current],
            'total': 1,
          };
        } else if (r.method == 'GET') {
          body = [
            {
              'id': 'record',
              'title': '나의 기록',
              'version': 0,
              'productIds': [raw['id']],
              'preferences': {},
              'snapshot': {
                'products': [original],
                'savedAt': '2026-11-01T00:00:00Z',
                'ruleVersion': '2026-11-fair-v1',
              },
            },
            {
              'id': 'legacy',
              'title': '이전 기록',
              'version': 0,
              'productIds': [raw['id']],
              'preferences': {},
              'snapshot': null,
            },
          ];
        } else {
          writes++;
          body = {};
        }
        return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
      }),
    );
    final products = ProductProvider(repository: ProductRepository(api: api));
    final session = SessionProvider(
      api: api,
      products: products,
      storage: MemorySessions(),
    );
    addTearDown(session.dispose);
    addTearDown(products.dispose);
    await products.loadProducts();
    await session.login('a@example.test', 'abcdefgh');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: products),
          ChangeNotifierProvider.value(value: session),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const ComparisonHistoryScreen(),
                  ),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('저장 당시 정보 없음'), findsOneWidget);
    await tester.tap(find.text('나의 기록'));
    await tester.pumpAndSettle();
    expect(find.textContaining('저장 당시 90,000원'), findsOneWidget);
    expect(find.textContaining('현재 정보 100,000원'), findsOneWidget);
    await tester.ensureVisible(find.text('현재 정보로 다시 비교'));
    await tester.tap(find.text('현재 정보로 다시 비교'));
    await tester.pumpAndSettle();
    expect(products.selectedProducts.single.price, 100000);
    expect(writes, 0);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('나의 기록'));
    await tester.pumpAndSettle();
    await session.clear();
    await tester.pumpAndSettle();
    expect(find.text('계정이 변경되어 기록을 닫아주세요.'), findsOneWidget);
    expect(find.textContaining('저장 당시 90,000원'), findsNothing);
  });
}
