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
import 'package:pickwise/presentation/widgets/watch_control.dart';
import 'package:pickwise/presentation/screens/watchlist_screen.dart';

import 'fixtures/session_storage.dart';

class _Fixture {
  late ProductProvider products;
  late SessionProvider session;
  final watches = <Map<String, dynamic>>[];
  final writes = <Map<String, dynamic>>[];
  int status = 204;
}

Future<_Fixture> _open(
  WidgetTester tester, {
  bool list = false,
  bool alerts = false,
  bool login = true,
  double scale = 1,
}) async {
  final f = _Fixture();
  final row = Map<String, dynamic>.from(
    (jsonDecode(
          File('assets/data/products.json').readAsStringSync(),
        ) as List).first
        as Map,
  );
  final api = PickwiseApi(
    baseUrl: 'https://watch-test.invalid',
    client: MockClient((r) async {
      dynamic body;
      if (r.url.path.endsWith('/auth/me')) {
        body = {'id': 'watch-user', 'email': 'test@example.test'};
      } else if (r.url.path.endsWith('/preferences')) {
        body = {'preferences': {}};
      } else if (r.url.path.endsWith('/watches')) {
        body = f.watches;
      } else if (r.url.path.contains('/watches/')) {
        if (r.method == 'DELETE') {
          f.watches.clear();
          return http.Response('', 204);
        }
        final input = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
        f.writes.add(input);
        if (f.status != 204) return http.Response('{}', f.status);
        f.watches.clear();
        f.watches.add({
          'productId': row['id'],
          'name': row['name'],
          'price': row['price'],
          'targetPrice': input['targetPrice'],
          'version': 1,
          'armed': input['targetPrice'] != null,
          'sourceChanged': false,
        });
        return http.Response('', 204);
      } else if (r.url.path.endsWith('/alerts')) {
        body = [];
      } else if (r.url.path == '/api/v1/products') {
        body = {
          'items': [row],
          'total': 1,
        };
      } else {
        body = {
          'accessToken': 'access',
          'refreshToken': 'refresh',
          'refreshExpiresAt': DateTime.now()
              .add(const Duration(days: 30))
              .toIso8601String(),
        };
      }
      return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
    }),
  );
  f.products = ProductProvider(repository: ProductRepository(api: api));
  f.session = SessionProvider(
    api: api,
    products: f.products,
    storage: MemorySessions(),
  );
  addTearDown(f.products.dispose);
  addTearDown(f.session.dispose);
  await f.products.loadProducts();
  if (login) await f.session.login('test@example.test', 'abcdefgh');
  tester.view.physicalSize = const Size(320, 850);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: f.products),
        ChangeNotifierProvider.value(value: f.session),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: list
            ? WatchlistScreen(alerts: alerts)
            : Scaffold(
                body: SingleChildScrollView(
                  child: WatchControl(product: f.products.products.single),
                ),
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return f;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('게스트는 계정 관심 정보를 요청하거나 수정하지 않는다', (tester) async {
    final f = await _open(tester, login: false);
    expect(find.text('관심 제품 · 목표가 설정'), findsNothing);
    expect(f.writes, isEmpty);
  });
  testWidgets('목표가를 검증하고 관심 제품으로 저장한다', (tester) async {
    final f = await _open(tester);
    await tester.tap(find.text('관심 제품 · 목표가 설정'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '0');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(f.writes, isEmpty);
    await tester.enterText(find.byType(TextFormField), '150000');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(f.writes.single['targetPrice'], 150000);
    expect(find.text('관심 제품 · 목표가 수정'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('목표가 없이도 관심 제품을 저장하고 충돌은 자동 재시도하지 않는다', (tester) async {
    final f = await _open(tester);
    f.status = 409;
    await tester.tap(find.text('관심 제품 · 목표가 설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(f.writes.single['targetPrice'], isNull);
    expect(f.writes.length, 1);
    expect(find.textContaining('새로고침'), findsOneWidget);
  });
  testWidgets('로그아웃하면 열린 목표가 폼에 이전 계정 설정을 표시하지 않는다', (tester) async {
    final f = await _open(tester);
    await tester.tap(find.text('관심 제품 · 목표가 설정'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '150000');
    await f.session.clear();
    await tester.pumpAndSettle();
    expect(find.text('로그인이 변경됐어요.'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(f.writes, isEmpty);
  });
  testWidgets('큰 글자에서도 목표가 입력창이 겹치지 않는다', (tester) async {
    await _open(tester, scale: 2);
    await tester.tap(find.text('관심 제품 · 목표가 설정'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('관심 목록·알림함 빈 상태와 계정 변경을 처리한다', (tester) async {
    final f = await _open(tester, list: true, alerts: true);
    expect(find.text('아직 도착한 가격 알림이 없어요.'), findsOneWidget);
    await f.session.clear();
    await tester.pumpAndSettle();
    expect(find.text('로그인 후 확인할 수 있어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
