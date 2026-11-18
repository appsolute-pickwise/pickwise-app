import 'package:flutter/foundation.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pickwise/data/services/pickwise_api.dart';
import 'package:pickwise/data/services/product_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('주소를 지정하지 않으면 플랫폼별 Docker 주소를 자동 선택한다', () {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final ios = PickwiseApi();
    addTearDown(ios.client.close);
    expect(ios.baseUrl, 'http://localhost:8080');
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final android = PickwiseApi();
    addTearDown(android.client.close);
    expect(android.baseUrl, 'http://10.0.2.2:8080');
    final custom = PickwiseApi(baseUrl: 'https://example.test');
    addTearDown(custom.client.close);
    expect(custom.baseUrl, 'https://example.test');
  });
  test('서버 목록을 변환하고 장애 때 마지막 정상 응답을 복원한다', () async {
    final catalog = jsonDecode(
      File('assets/data/products.json').readAsStringSync(),
    ) as List;
    catalog.first['priceFetchedAt'] = '2026-11-16T01:27:00Z';
    catalog.first['priceAttemptedAt'] = '2026-11-16T01:27:00Z';
    catalog.first['priceRefreshStatus'] = 'updated';
    var fail = false;
    final api = PickwiseApi(
      baseUrl: 'https://test.invalid',
      client: MockClient((r) async {
        if (fail) return http.Response('', 503);
        return http.Response.bytes(
          utf8.encode(jsonEncode({'items': catalog, 'total': catalog.length})),
          200,
        );
      }),
    );
    final repository = ProductRepository(api: api);
    final fetched = await repository.loadProducts();
    expect(fetched.length, 20);
    expect(fetched.first.priceFetchedAt, DateTime.utc(2026, 11, 16, 1, 27));
    expect(fetched.first.priceRefreshStatus, 'updated');
    expect(repository.usingCache, false);
    fail = true;
    final cached = await repository.loadProducts();
    expect(cached.length, 20);
    expect(cached.first.priceFetchedAt, fetched.first.priceFetchedAt);
    expect(cached.first.priceRefreshStatus, 'updated');
    expect(repository.usingCache, true);
    expect(repository.cachedAt, isNotNull);
    api.client.close();
  });
  test('첫 연결 실패는 오류이고 정상 빈 응답은 빈 목록이다', () async {
    final failed = PickwiseApi(
      baseUrl: 'https://test.invalid',
      client: MockClient((_) async => http.Response('', 503)),
    );
    await expectLater(
      ProductRepository(api: failed).loadProducts(),
      throwsA(isA<ApiException>()),
    );
    failed.client.close();
    final empty = PickwiseApi(
      baseUrl: 'https://test.invalid',
      client: MockClient(
        (_) async => http.Response('{"items":[],"total":0}', 200),
      ),
    );
    expect(await ProductRepository(api: empty).loadProducts(), isEmpty);
    empty.client.close();
  });
  test('401은 세션을 비우고 저장 요청을 자동 재전송하지 않는다', () async {
    var count = 0;
    final api = PickwiseApi(
      baseUrl: 'https://test.invalid',
      client: MockClient((_) async {
        count++;
        return http.Response('', 401);
      }),
    )..token = 'test-token';
    await expectLater(
      api.request('POST', '/api/v1/me/comparisons', {}),
      throwsA(isA<ApiException>()),
    );
    expect(api.token, isNull);
    expect(count, 1);
    api.client.close();
  });
}
