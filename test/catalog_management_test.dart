import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pickwise/data/services/pickwise_api.dart';
import 'package:pickwise/data/services/product_repository.dart';
import 'package:pickwise/presentation/providers/product_provider.dart';
import 'package:pickwise/presentation/providers/session_provider.dart';
import 'package:pickwise/presentation/screens/admin_products_screen.dart';
import 'package:pickwise/presentation/screens/my_page_screen.dart';
import 'package:pickwise/presentation/screens/product_editor_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/session_storage.dart';

class _Fixture {
  late ProductProvider products;
  late SessionProvider session;
  late Map<String, dynamic> product;
  final writes = <Map<String, dynamic>>[];
  int saveStatus = 200;
}

Future<_Fixture> _open(
  WidgetTester tester, {
  bool admin = true,
  bool myPage = false,
  bool create = false,
  double width = 390,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 850);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final fixture = _Fixture();
  fixture.product =
      Map<String, dynamic>.from(
          (jsonDecode(
                File('assets/data/products.json').readAsStringSync(),
              ) as List).first
              as Map,
        )
        ..['version'] = 3
        ..['priceAutoRefresh'] = false;
  final api = PickwiseApi(
    baseUrl: 'https://catalog-test.invalid',
    client: MockClient((request) async {
      Object body;
      if (request.url.path.endsWith('/auth/me')) {
        body = {
          'id': 'manager',
          'email': 'manager@example.test',
          'admin': admin,
        };
      } else if (request.url.path.endsWith('/preferences')) {
        body = {'preferences': <String, dynamic>{}};
      } else if (request.url.path.endsWith('/changes')) {
        body = <Object>[];
      } else if (request.url.path.startsWith('/api/v1/admin/products')) {
        if (request.method == 'GET') {
          body = fixture.product;
        } else {
          final input = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          fixture.writes.add(input);
          if (fixture.saveStatus >= 400) {
            return http.Response('{}', fixture.saveStatus);
          }
          fixture.product = {
            ...fixture.product,
            ...input,
            'version': (input['version'] as int) + 1,
          };
          body = fixture.product;
        }
      } else if (request.url.path == '/api/v1/products') {
        body = {
          'items': [fixture.product],
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
  fixture.products = ProductProvider(repository: ProductRepository(api: api));
  fixture.session = SessionProvider(
    api: api,
    products: fixture.products,
    storage: MemorySessions(),
  );
  addTearDown(fixture.session.dispose);
  addTearDown(fixture.products.dispose);
  await fixture.products.loadProducts();
  await fixture.session.login('manager@example.test', 'abcdefgh');
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: fixture.products),
        ChangeNotifierProvider.value(value: fixture.session),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: myPage ? const MyPageScreen() : const AdminProductsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (create) {
    await tester.tap(find.text('상품 등록'));
    await tester.pumpAndSettle();
  }
  return fixture;
}

Finder _field(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(TextFormField));

Future<void> _enter(WidgetTester tester, String label, String value) async {
  await tester.ensureVisible(_field(label));
  await tester.enterText(_field(label), value);
  await tester.pump();
}

Future<void> _save(WidgetTester tester) async {
  tester.testTextInput.hide();
  await tester.ensureVisible(find.text('상품 정보 저장'));
  await tester.tap(find.text('상품 정보 저장'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('일반 계정의 마이페이지에는 상품 관리가 없다', (tester) async {
    final f = await _open(tester, admin: false, myPage: true);
    expect(f.session.isAdmin, isFalse);
    expect(find.text('상품 관리'), findsNothing);
  });

  testWidgets('일반 계정은 관리 화면을 직접 열어도 저장할 수 없다', (tester) async {
    final f = await _open(tester, admin: false);
    expect(find.text('관리자 계정으로 로그인해주세요.'), findsOneWidget);
    expect(find.text('상품 등록'), findsNothing);
    expect(f.writes, isEmpty);
  });

  testWidgets('관리자는 마이페이지에서 상품 관리로 이동한다', (tester) async {
    await _open(tester, myPage: true);
    await tester.ensureVisible(find.text('상품 관리'));
    await tester.tap(find.text('상품 관리'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminProductsScreen), findsOneWidget);
  });

  testWidgets('관리자는 최신 버전으로 수정하고 목록·비교 가격을 갱신한다', (tester) async {
    final f = await _open(tester);
    await tester.tap(find.text('Sony WF-1000XM5'));
    await tester.pumpAndSettle();
    await _enter(tester, '가격 (원)', '123456');
    await _save(tester);
    expect(f.writes.single['price'], 123456);
    expect(f.writes.single['version'], 3);
    expect(f.writes.single['priceAutoRefresh'], isFalse);
    expect(f.writes.single['specs'], isNotEmpty);
    expect(find.byType(ProductEditorScreen), findsNothing);
    expect(find.textContaining('123,456원'), findsOneWidget);
    expect(f.products.products.single.price, 123456);
  });

  testWidgets('상품 등록은 JSON 편집 없이 입력값을 서버로 보낸다', (tester) async {
    final f = await _open(tester, create: true);
    await _enter(tester, '제품 ID', 'new-earbud');
    await _enter(tester, '브랜드', '테스트');
    await _enter(tester, '제품명', '새 이어폰');
    await _enter(tester, '가격 (원)', '100000');
    await _enter(
      tester,
      '제품별 가격 출처 링크',
      'https://prod.danawa.com/info/?pcode=27250154',
    );
    await _save(tester);
    expect(f.writes.single['id'], 'new-earbud');
    expect(f.writes.single['version'], 0);
    expect(f.writes.single['price'], 100000);
    expect(f.writes.single['specs'], isEmpty);
  });

  testWidgets('스크롤로 숨겨진 필수 항목도 검증하고 서버에 보내지 않는다', (tester) async {
    final f = await _open(tester, create: true);
    await _save(tester);
    expect(f.writes, isEmpty);
    expect(find.text('0보다 큰 정수 가격을 입력해주세요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('수정 충돌 때 작성 내용을 보존하고 자동 재전송하지 않는다', (tester) async {
    final f = await _open(tester);
    f.saveStatus = 409;
    await tester.tap(find.text('Sony WF-1000XM5'));
    await tester.pumpAndSettle();
    await _enter(tester, '가격 (원)', '123456');
    await _save(tester);
    expect(f.writes.length, 1);
    expect(find.textContaining('작성 내용은 유지했어요'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(_field('가격 (원)')).controller!.text,
      '123456',
    );
    expect(find.byType(ProductEditorScreen), findsOneWidget);
  });

  testWidgets('작은 화면·확대 글자에서 등록 폼이 겹치지 않는다', (tester) async {
    await _open(tester, create: true, width: 320, scale: 2);
    await tester.ensureVisible(find.text('사양 추가'));
    await tester.tap(find.text('사양 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이어버드 재생 시간 (ANC 켬)'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('상품 정보 저장'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('관리자 로그아웃 후 권한과 열린 관리 화면을 정리한다', (tester) async {
    final f = await _open(tester);
    await f.session.clear();
    await tester.pumpAndSettle();
    expect(f.session.isAdmin, isFalse);
    expect(find.text('관리자 계정으로 로그인해주세요.'), findsOneWidget);
    expect(f.writes, isEmpty);
  });
}
