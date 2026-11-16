import 'package:pickwise/presentation/screens/liking_screen.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pickwise/data/models/product_preferences.dart';
import 'package:pickwise/data/services/pickwise_api.dart';
import 'package:pickwise/data/services/product_repository.dart';
import 'package:pickwise/presentation/providers/app_navigation_controller.dart';
import 'package:pickwise/presentation/providers/product_provider.dart';
import 'package:pickwise/presentation/providers/session_provider.dart';
import 'package:pickwise/presentation/screens/app_shell.dart';
import 'package:pickwise/presentation/screens/login_screen.dart';
import 'package:pickwise/presentation/screens/my_page_screen.dart';
import 'package:pickwise/presentation/screens/product_comparison_screen.dart';

import 'fixtures/session_storage.dart';

class Fixture {
  late ProductProvider products;
  late SessionProvider session;
  final navigation = AppNavigationController()..select(3);
  final requests = <String>[];
  Map<String, dynamic> saved = {
    'priorities': ['배터리'],
    'budget': '5만~15만원',
  };
  bool failPreferences = false;
}

Future<Fixture> open(
  WidgetTester tester, {
  bool loggedIn = false,
  bool failPreferences = false,
}) async {
  final f = Fixture()..failPreferences = failPreferences;
  final api = PickwiseApi(
    baseUrl: 'https://test.invalid',
    client: MockClient((request) async {
      f.requests.add('${request.method} ${request.url.path}');
      if (request.url.path.endsWith('/logout')) return http.Response('', 204);
      if (request.url.path.endsWith('/preferences')) {
        if (f.failPreferences) return http.Response('', 503);
        if (request.method == 'PUT') {
          f.saved = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
        }
        return http.Response.bytes(
          utf8.encode(jsonEncode({'preferences': f.saved})),
          200,
        );
      }
      if (request.url.path.endsWith('/auth/me')) {
        return http.Response('{"id":"a","email":"student@example.test"}', 200);
      }
      if (request.url.path.endsWith('/comparisons')) {
        return http.Response('[]', 200);
      }
      return http.Response(
        jsonEncode({
          'accessToken': 'access',
          'refreshToken': 'refresh',
          'refreshExpiresAt': DateTime.now()
              .add(const Duration(days: 30))
              .toIso8601String(),
        }),
        200,
      );
    }),
  );
  f.products = ProductProvider(repository: AssetProductRepository());
  f.session = SessionProvider(
    api: api,
    products: f.products,
    storage: MemorySessions(),
  );
  addTearDown(f.products.dispose);
  addTearDown(f.session.dispose);
  addTearDown(f.navigation.dispose);
  await tester.runAsync(f.products.loadProducts);
  if (loggedIn) await f.session.login('student@example.test', 'abcdefgh');
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: f.products),
        ChangeNotifierProvider.value(value: f.session),
        ChangeNotifierProvider.value(value: f.navigation),
      ],
      child: const MaterialApp(home: AppShell()),
    ),
  );
  await tester.pumpAndSettle();
  return f;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('마이 탭과 현재 비교 이동은 56px 탐색 바를 유지한다', (tester) async {
    final f = await open(tester);
    expect(find.text('마이페이지'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(
      tester
          .getSize(find.byKey(const ValueKey('app-bottom-navigation')))
          .height,
      56,
    );
    f.products.addToComparison(f.products.products.first.id);
    await tester.pumpAndSettle();
    expect(find.text('1개 제품'), findsOneWidget);
    await tester.tap(find.text('현재 비교'));
    await tester.pumpAndSettle();
    expect(f.navigation.index, 2);
    expect(find.byType(ProductComparisonScreen), findsOneWidget);
    await tester.tap(find.text('마이'));
    await tester.pumpAndSettle();
    expect(find.byType(MyPageScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(f.navigation.index, 0);
  });
  testWidgets('게스트는 로그인 진입과 이 기기의 취향 저장을 사용할 수 있다', (tester) async {
    final f = await open(tester);
    expect(find.text('게스트'), findsOneWidget);
    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('무게'));
    await tester.tap(find.text('기본 취향 저장'));
    await tester.pumpAndSettle();
    expect(f.products.selectionPreferences.priorities, ['무게']);
    expect(f.requests.where((r) => r.contains('/preferences')), isEmpty);
    await tester.ensureVisible(find.text('로그인 · 회원가입'));
    await tester.tap(find.text('로그인 · 회원가입'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });
  testWidgets('서버 기본 취향 수정은 진행 중인 비교와 기준을 유지한다', (tester) async {
    final f = await open(tester, loggedIn: true);
    f.products.updateSelectionPreferences(
      const ProductPreferences(priorities: ['ANC']),
    );
    f.products.addToComparison(f.products.products.first.id);
    await tester.pumpAndSettle();
    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();
    expect(find.text('기본 취향 설정'), findsOneWidget);
    await tester.tap(find.text('무게'));
    await tester.tap(find.text('기본 취향 저장'));
    await tester.pumpAndSettle();
    expect(f.saved['priorities'], ['배터리', '무게']);
    expect(f.products.defaultPreferences!.priorities, ['배터리', '무게']);
    expect(f.products.selectionPreferences.priorities, ['ANC']);
    expect(f.products.selectedCount, 1);
    expect(find.text('기본 취향을 저장했어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('로그아웃은 취소할 수 있고 확인한 경우에만 서버 세션을 폐기한다', (tester) async {
    final f = await open(tester, loggedIn: true);
    await tester.scrollUntilVisible(
      find.text('로그아웃'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(MyPageScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(f.session.loggedIn, isTrue);
    expect(f.requests.where((r) => r.endsWith('/logout')), isEmpty);
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '로그아웃'));
    await tester.pumpAndSettle();
    expect(f.session.loggedIn, isFalse);
    expect(f.requests.where((r) => r.endsWith('/logout')), hasLength(1));
    expect(find.text('student@example.test'), findsNothing);
  });
  testWidgets('취향 조회 실패는 재시도할 수 있고 현재 기준은 바꾸지 않는다', (tester) async {
    final f = await open(tester, loggedIn: true, failPreferences: true);
    f.products.updateSelectionPreferences(
      const ProductPreferences(priorities: ['ANC']),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('기본 취향 다시 불러오기'));
    await tester.tap(find.text('기본 취향 다시 불러오기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('서버 요청에 실패'), findsOneWidget);
    f.failPreferences = false;
    await tester.tap(find.text('기본 취향 다시 불러오기'));
    await tester.pumpAndSettle();
    expect(f.products.defaultPreferences!.priorities, ['배터리']);
    expect(f.products.selectionPreferences.priorities, ['ANC']);
  });
  testWidgets('320px 화면과 큰 글자에서도 계정·메뉴가 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester, loggedIn: true);
    await tester.scrollUntilVisible(
      find.text('앱 정보'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(MyPageScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('앱 정보'));
    await tester.pumpAndSettle();
    expect(find.text('PickWise'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('취향 저장 실패는 입력을 유지하고 현재 비교에 적용하지 않는다', (tester) async {
    final f = await open(tester, loggedIn: true);
    f.failPreferences = true;
    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('무게'));
    await tester.tap(find.text('기본 취향 저장'));
    await tester.pumpAndSettle();
    expect(find.byType(LikingScreen), findsOneWidget);
    expect(find.textContaining('서버 요청에 실패'), findsOneWidget);
    expect(f.products.defaultPreferences!.priorities, ['배터리']);
    expect(f.products.selectionPreferences.priorities, ['배터리']);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, '기본 취향 저장'),
          )
          .onPressed,
      isNotNull,
    );
  });
}
