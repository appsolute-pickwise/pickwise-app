import 'fixtures/session_storage.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pickwise/data/models/product_preferences.dart';
import 'package:pickwise/data/services/pickwise_api.dart';
import 'package:pickwise/data/services/product_repository.dart';
import 'package:pickwise/presentation/providers/product_provider.dart';
import 'package:pickwise/presentation/providers/session_provider.dart';

http.Response json(Object value, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(value)), status);
Map<String, String> tokens(String access) => {
  'accessToken': access,
  'refreshToken': 'refresh-$access',
  'refreshExpiresAt': DateTime.now()
      .add(const Duration(days: 30))
      .toIso8601String(),
  'expiresAt': DateTime.now()
      .add(const Duration(minutes: 15))
      .toIso8601String(),
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('로그인과 재실행 복원·동시 401 갱신은 한 번만 수행하고 저장을 재전송하지 않는다', () async {
    var access = 'old', refreshes = 0, writes = 0;
    final storage = MemorySessions();
    final api = PickwiseApi(
      baseUrl: 'https://test.invalid',
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) return json(tokens(access));
        if (r.url.path.endsWith('/refresh')) {
          refreshes++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          access = 'new';
          return json(tokens(access));
        }
        if (r.headers['Authorization'] != 'Bearer $access') {
          return json({}, 401);
        }
        if (r.url.path.endsWith('/auth/me')) {
          return json({'id': 'a', 'email': 'a@example.test'});
        }
        if (r.url.path.endsWith('/preferences')) {
          return json({
            'preferences': {
              'priorities': ['무게'],
            },
          });
        }
        if (r.method == 'POST') {
          writes++;
          return json({}, 401);
        }
        return json([]);
      }),
    );
    final products = ProductProvider(repository: AssetProductRepository());
    final session = SessionProvider(
      api: api,
      products: products,
      storage: storage,
    );
    addTearDown(session.dispose);
    addTearDown(products.dispose);
    await session.login('a@example.test', 'abcdefgh');
    expect(session.loggedIn, isTrue);
    expect(products.selectionPreferences.priorities, ['무게']);
    expect(storage.value, isNot(contains('abcdefgh')));
    access = 'expired';
    await Future.wait([
      api.request('GET', '/api/v1/me/comparisons'),
      api.request('GET', '/api/v1/me/comparisons'),
    ]);
    expect(refreshes, 1);
    await expectLater(
      api.request('POST', '/api/v1/me/comparisons', {}),
      throwsA(isA<ApiException>()),
    );
    expect(writes, 1);
    final restoredProducts = ProductProvider(
      repository: AssetProductRepository(),
    );
    final restoredApi = PickwiseApi(
      baseUrl: api.baseUrl,
      client: MockClient(
        (r) async => r.url.path.endsWith('/auth/me')
            ? json({'id': 'a', 'email': 'a@example.test'})
            : json({
                'preferences': {
                  'priorities': ['무게'],
                },
              }),
      ),
    );
    final restored = SessionProvider(
      api: restoredApi,
      products: restoredProducts,
      storage: storage,
    );
    addTearDown(restored.dispose);
    addTearDown(restoredProducts.dispose);
    await restored.initialize();
    expect(restored.email, 'a@example.test');
    expect(restoredProducts.selectionPreferences.priorities, ['무게']);
    await restored.clear();
    expect(storage.value, isNull);
    expect(restored.loggedIn, isFalse);
  });
  test('계정 전환은 비교 목록을 비우고 늦게 온 취향이 편집 중인 기준을 덮지 않는다', () async {
    final profile = Completer<http.Response>();
    var owner = 'a';
    final api = PickwiseApi(
      baseUrl: 'https://test.invalid',
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) return json(tokens(owner));
        if (r.url.path.endsWith('/auth/me')) {
          return json({'id': owner, 'email': '$owner@example.test'});
        }
        return owner == 'a'
            ? profile.future
            : json({
                'preferences': {
                  'priorities': ['배터리'],
                },
              });
      }),
    );
    final products = ProductProvider(repository: AssetProductRepository());
    final session = SessionProvider(
      api: api,
      products: products,
      storage: MemorySessions(),
    );
    addTearDown(session.dispose);
    addTearDown(products.dispose);
    await products.loadProducts();
    final login = session.login('a@example.test', 'abcdefgh');
    while (!session.loggedIn) {
      await Future<void>.delayed(Duration.zero);
    }
    products.updateSelectionPreferences(
      const ProductPreferences(priorities: ['무게']),
    );
    products.addToComparison(products.products.first.id);
    profile.complete(
      json({
        'preferences': {
          'priorities': ['배터리'],
        },
      }),
    );
    await login;
    expect(products.selectionPreferences.priorities, ['무게']);
    owner = 'b';
    await session.login('b@example.test', 'abcdefgh');
    expect(products.selectedCount, 0);
    expect(products.selectionPreferences.priorities, ['배터리']);
    expect(session.email, 'b@example.test');
  });
  test('갱신 실패는 토큰·계정 상태를 정리하고 지연된 기록 응답을 거부한다', () async {
    var fail = false;
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final api = PickwiseApi(
      baseUrl: 'https://test.invalid',
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) return json(tokens('a'));
        if (r.url.path.endsWith('/auth/me')) {
          return json({'id': 'a', 'email': 'a@example.test'});
        }
        if (r.url.path.endsWith('/preferences')) {
          return json({'preferences': {}});
        }
        if (r.url.path.endsWith('/refresh')) return json({}, 401);
        if (fail) return json({}, 401);
        started.complete();
        return response.future;
      }),
    );
    final storage = MemorySessions();
    final products = ProductProvider(repository: AssetProductRepository());
    final session = SessionProvider(
      api: api,
      products: products,
      storage: storage,
    );
    addTearDown(session.dispose);
    addTearDown(products.dispose);
    await session.login('a@example.test', 'abcdefgh');
    final pending = api.request('GET', '/api/v1/me/comparisons');
    await started.future;
    fail = true;
    await expectLater(
      api.request('GET', '/api/v1/me/comparisons'),
      throwsA(isA<ApiException>()),
    );
    expect(session.loggedIn, isFalse);
    final rejected = expectLater(pending, throwsA(isA<ApiException>()));
    response.complete(
      json([
        {'title': '이전 계정 기록'},
      ]),
    );
    await rejected;
    expect(storage.value, isNull);
  });
  test('게스트 편집을 로그인 취향으로 덮지 않고 로그아웃 후 게스트 취향을 복원한다', () async {
    final api = PickwiseApi(
      baseUrl: 'https://test.invalid',
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) return json(tokens('a'));
        if (r.url.path.endsWith('/auth/me')) {
          return json({'id': 'a', 'email': 'a@example.test'});
        }
        return json({
          'preferences': {
            'priorities': ['배터리'],
          },
        });
      }),
    );
    final products = ProductProvider(repository: AssetProductRepository());
    final session = SessionProvider(
      api: api,
      products: products,
      storage: MemorySessions(),
    );
    addTearDown(products.dispose);
    addTearDown(session.dispose);
    await products.loadProducts();
    products.updateSelectionPreferences(
      const ProductPreferences(priorities: ['무게']),
    );
    await session.login('a@example.test', 'abcdefgh');
    expect(products.selectionPreferences.priorities, ['무게']);
    expect(products.defaultPreferences?.priorities, ['배터리']);
    products.updateSelectionPreferences(
      const ProductPreferences(priorities: ['ANC']),
    );
    await session.clear();
    expect(products.selectionPreferences.priorities, ['무게']);
    expect(products.selectedCount, 0);
  });
  test('오프라인 재실행에는 보관한 계정과 취향을 유지하고 서버 기록을 섞지 않는다', () async {
    final storage = MemorySessions()
      ..value = jsonEncode({
        ...tokens('cached'),
        'userId': 'a',
        'email': 'a@example.test',
      });
    SharedPreferences.setMockInitialValues({
      'defaultPreferences:a': jsonEncode({
        'priorities': ['무게'],
      }),
    });
    final api = PickwiseApi(
      baseUrl: 'https://test.invalid',
      client: MockClient((r) async {
        throw http.ClientException('offline');
      }),
    );
    final products = ProductProvider(repository: AssetProductRepository());
    final session = SessionProvider(
      api: api,
      products: products,
      storage: storage,
    );
    addTearDown(products.dispose);
    addTearDown(session.dispose);
    await session.initialize();
    expect(session.email, 'a@example.test');
    expect(products.selectionPreferences.priorities, ['무게']);
    expect(session.message, contains('서버 연결'));
    expect(storage.value, isNotNull);
    expect(products.selectedCount, 0);
  });
  test('30일 만료 후에는 오프라인에서도 보관한 세션을 복원하지 않는다', () async {
    final storage = MemorySessions()
      ..value = jsonEncode({
        ...tokens('expired'),
        'refreshExpiresAt': DateTime.now()
            .subtract(const Duration(seconds: 1))
            .toIso8601String(),
        'userId': 'a',
        'email': 'a@example.test',
      });
    var calls = 0;
    final api = PickwiseApi(
      baseUrl: 'https://test.invalid',
      client: MockClient((r) async {
        calls++;
        return json({}, 401);
      }),
    );
    final products = ProductProvider(repository: AssetProductRepository());
    final session = SessionProvider(
      api: api,
      products: products,
      storage: storage,
    );
    addTearDown(products.dispose);
    addTearDown(session.dispose);
    await session.initialize();
    expect(session.loggedIn, isFalse);
    expect(storage.value, isNull);
    expect(calls, 0);
  });
  test('이전 계정의 늦은 갱신 실패가 새 계정을 로그아웃시키지 않는다', () async {
    final response = Completer<http.Response>(), started = Completer<void>();
    var owner = 'a';
    final api = PickwiseApi(
      baseUrl: 'https://test.invalid',
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) return json(tokens(owner));
        if (r.url.path.endsWith('/auth/me')) {
          return json({'id': owner, 'email': '$owner@example.test'});
        }
        if (r.url.path.endsWith('/refresh')) {
          started.complete();
          return response.future;
        }
        return json({'preferences': {}});
      }),
    );
    final storage = MemorySessions();
    final products = ProductProvider(repository: AssetProductRepository());
    final session = SessionProvider(
      api: api,
      products: products,
      storage: storage,
    );
    addTearDown(products.dispose);
    addTearDown(session.dispose);
    await session.login('a@example.test', 'abcdefgh');
    final old = session.refresh();
    await started.future;
    owner = 'b';
    await session.login('b@example.test', 'abcdefgh');
    response.complete(json({}, 401));
    expect(await old, isFalse);
    expect(session.email, 'b@example.test');
    expect(api.token, 'b');
    expect(jsonDecode(storage.value!)['userId'], 'b');
  });
}
