import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'fixtures/session_storage.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pickwise/main.dart' as app;
import 'package:pickwise/presentation/providers/session_provider.dart';
import 'package:pickwise/presentation/providers/product_provider.dart';
import 'package:pickwise/data/models/product_preferences.dart';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pickwise/data/services/pickwise_api.dart';
import 'package:pickwise/data/services/product_repository.dart';

void main() {
  const url = String.fromEnvironment('LIVE_API_URL');
  TestWidgetsFlutterBinding.ensureInitialized();
  if (url.isNotEmpty) HttpOverrides.global = null;
  test('실제 서버에서 제품 조회와 계정별 비교 저장·복원·삭제', () async {
    SharedPreferences.setMockInitialValues({});
    final api = PickwiseApi(baseUrl: url);
    addTearDown(api.client.close);
    final products = await ProductRepository(api: api).loadProducts();
    expect(products, isNotEmpty);
    final credentials = {
      'email': 'flutter-${DateTime.now().microsecondsSinceEpoch}@example.test',
      'password': 'local-integration-password',
    };
    final auth = await api.request(
      'POST',
      '/api/v1/auth/register',
      credentials,
    );
    api.token = auth['token'] as String;
    final record = await api.request('POST', '/api/v1/me/comparisons', {
      'title': 'Flutter 실제 연동 확인',
      'productIds': [products.first.id],
      'preferences': {
        'priorities': ['ANC'],
        'weights': {'ANC': 3},
      },
      'version': 0,
    });
    await api.request('POST', '/api/v1/auth/logout');
    api.token = null;
    final login = await api.request('POST', '/api/v1/auth/login', credentials);
    api.token = login['token'] as String;
    final rows = await api.request('GET', '/api/v1/me/comparisons') as List;
    expect(rows.single['id'], record['id']);
    expect(rows.single['preferences']['weights']['ANC'], 3);
    await api.request('DELETE', '/api/v1/me/comparisons/${record['id']}');
    expect(await api.request('GET', '/api/v1/me/comparisons'), isEmpty);
    await api.request('POST', '/api/v1/auth/logout');
  }, skip: url.isEmpty ? 'LIVE_API_URL 설정 시에만 실제 서버에 실행' : false);
  test('실제 Docker에 앱 루트 세션·갱신·기본 취향·스냅샷 저장·재접속을 연결한다', () async {
    SharedPreferences.setMockInitialValues({});
    final api = PickwiseApi(baseUrl: url);
    final products = ProductProvider(repository: ProductRepository(api: api));
    final storage = MemorySessions();
    final session = SessionProvider(
      api: api,
      products: products,
      storage: storage,
    );
    addTearDown(session.dispose);
    addTearDown(products.dispose);
    await products.loadProducts();
    expect(products.usingCache, isFalse);
    final email =
        'session-${DateTime.now().microsecondsSinceEpoch}@example.test';
    await session.login(email, 'abcdefgh', register: true);
    products.updateSelectionPreferences(
      const ProductPreferences(
        priorities: ['배터리', '무게'],
        batteryCondition: 'ancOn',
      ),
    );
    await session.saveDefaultPreferences();
    final ranked = products.selectionPreferences.recommend(products.products);
    expect(ranked, isNotEmpty);
    final item = ranked.first;
    products.addToComparison(item.id);
    final record = await api.request('POST', '/api/v1/me/comparisons', {
      'title': '스냅샷 검증',
      'productIds': [item.id],
      'preferences': products.selectionPreferences.toJson(),
      'version': 0,
    });
    final before = api.token;
    expect(await session.refresh(), isTrue);
    expect(api.token, isNot(before));
    final rows = await api.request('GET', '/api/v1/me/comparisons') as List;
    expect(rows.single['snapshot']['products'][0]['price'], item.price);
    expect(
      rows.single['snapshot']['ruleVersion'],
      ProductPreferences.ruleVersion,
    );
    final restoredApi = PickwiseApi(baseUrl: url);
    final restoredProducts = ProductProvider(
      repository: ProductRepository(api: restoredApi),
    );
    final restored = SessionProvider(
      api: restoredApi,
      products: restoredProducts,
      storage: storage,
    );
    addTearDown(restored.dispose);
    addTearDown(restoredProducts.dispose);
    await restoredProducts.loadProducts();
    await restored.initialize();
    expect(restored.email, email);
    expect(restoredProducts.selectionPreferences.priorities, ['배터리', '무게']);
    await restoredApi.request(
      'DELETE',
      '/api/v1/me/comparisons/${record['id']}',
    );
    await restored.logout();
    expect(storage.value, isNull);
    expect(restoredProducts.selectedCount, 0);
    await session.login(email, 'abcdefgh');
    expect(products.defaultPreferences?.priorities, ['배터리', '무게']);
    await session.logout();
  }, skip: url.isEmpty ? 'LIVE_API_URL 설정 시 실제 Docker HTTP 확인' : false);
  testWidgets('main.dart를 인자 없이 실행해 Docker 제품을 읽는다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    ProductProvider? products;
    await tester.runAsync(() async {
      FlutterSecureStorage.setMockInitialValues({});
      app.main();
      await tester.pump();
      products = Provider.of<ProductProvider>(
        tester.element(find.byType(app.PickWiseApp)),
        listen: false,
      );
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (products!.isLoading && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();
    expect(products!.hasLoadError, isFalse);
    expect(products!.products.length, 20);
    expect(products!.usingCache, isFalse);
    expect(products!.api.baseUrl, 'http://localhost:8080');
    await tester.pumpWidget(const SizedBox());
    products!.dispose();
    debugDefaultTargetPlatformOverride = null;
  }, skip: url != 'http://localhost:8080');
  test('실제 서버에서 비밀번호를 변경하면 이전 세션은 폐기된다', () async {
    SharedPreferences.setMockInitialValues({});
    final api = PickwiseApi(baseUrl: url);
    final products = ProductProvider(repository: ProductRepository(api: api));
    final session = SessionProvider(
      api: api,
      products: products,
      storage: MemorySessions(),
    );
    addTearDown(session.dispose);
    addTearDown(products.dispose);
    final email =
        'password-${DateTime.now().microsecondsSinceEpoch}@example.test';
    await session.login(email, 'abcdefgh', register: true);
    final old = api.token;
    await expectLater(
      session.changePassword('incorrect', '12345678'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 422)),
    );
    expect(session.loggedIn, isTrue);
    await session.changePassword('abcdefgh', '12345678');
    expect(session.loggedIn, isFalse);
    api.token = old;
    await expectLater(
      api.request('GET', '/api/v1/auth/me'),
      throwsA(isA<ApiException>()),
    );
    api.token = null;
    await session.login(email, '12345678');
    expect(session.loggedIn, isTrue);
    await session.logout();
  }, skip: url.isEmpty ? '실제 서버 설정 시에만 실행' : false);
}
