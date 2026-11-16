import 'dart:async';
import 'dart:convert';

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
import 'package:pickwise/presentation/providers/app_navigation_controller.dart';
import 'package:pickwise/presentation/screens/auth_gate.dart';
import 'package:pickwise/presentation/screens/login_screen.dart';
import 'package:pickwise/presentation/screens/sign_up_screen.dart';
import 'package:pickwise/presentation/screens/home_screen.dart';

import 'fixtures/session_storage.dart';

class DeferredStorage extends MemorySessions {
  final ready = Completer<String?>();
  @override
  Future<String?> read() => ready.future;
}

Future<SessionProvider> open(
  WidgetTester tester, {
  MemorySessions? storage,
  bool restore = false,
  bool fail = false,
  List<String>? requests,
  Completer<http.Response>? loginResponse,
}) async {
  final api = PickwiseApi(
    baseUrl: 'https://test.invalid',
    client: MockClient((r) async {
      requests?.add(r.url.path);
      if (loginResponse != null && r.url.path.endsWith('/login')) {
        return loginResponse.future;
      }
      if (fail) return http.Response('', 401);
      Object data;
      if (r.url.path.endsWith('/auth/me')) {
        data = {'id': 'a', 'email': 'a@example.test'};
      } else if (r.url.path.endsWith('/preferences')) {
        data = {'preferences': {}};
      } else {
        data = {
          'accessToken': 'a',
          'refreshToken': 'r',
          'refreshExpiresAt': DateTime.now()
              .add(const Duration(days: 30))
              .toIso8601String(),
        };
      }
      return http.Response.bytes(utf8.encode(jsonEncode(data)), 200);
    }),
  );
  final products = ProductProvider(repository: AssetProductRepository());
  final session = SessionProvider(
    api: api,
    products: products,
    storage: storage ?? MemorySessions(),
  );
  addTearDown(session.dispose);
  addTearDown(products.dispose);
  await tester.runAsync(products.loadProducts);
  if (restore) unawaited(session.initialize());
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: products),
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider(create: (_) => AppNavigationController()),
      ],
      child: MaterialApp(home: const AuthGate()),
    ),
  );
  await tester.pump();
  return session;
}

void expectLogo(WidgetTester tester) {
  final bounds = tester.getSize(
    find.byKey(const ValueKey('auth-logo-bounds')).last,
  );
  expect(bounds.width, greaterThanOrEqualTo(240));
  expect(bounds.height / bounds.width, closeTo(235 / 817, .001));
  final image = tester.widget<Image>(
    find
        .byWidgetPredicate(
          (widget) => widget is Image && widget.semanticLabel == 'PickWise 로고',
        )
        .last,
  );
  expect(
    (image.image as AssetImage).assetName,
    'assets/images/logo/pickwiselogo.png',
  );
}

Future<void> fill(
  WidgetTester tester, {
  bool signup = false,
  String confirmation = 'abcdefgh',
}) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'a@example.test');
  await tester.enterText(find.byType(TextFormField).at(1), 'abcdefgh');
  if (signup) {
    await tester.enterText(find.byType(TextFormField).at(2), confirmation);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('첫 실행은 원래 로고가 있는 로그인이고 회원가입은 별도 화면이다', (tester) async {
    await open(tester);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expectLogo(tester);
    await tester.ensureVisible(find.text('회원가입'));
    await tester.tap(find.text('회원가입'));
    await tester.pumpAndSettle();
    expect(find.byType(SignUpScreen), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3));
    expectLogo(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });
  testWidgets('로그인 성공은 홈으로 이동하고 실패하면 입력과 오류를 유지한다', (tester) async {
    final session = await open(tester);
    await tester.pumpAndSettle();
    await fill(tester);
    await tester.ensureVisible(find.widgetWithText(FilledButton, '로그인'));
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pumpAndSettle();
    expect(session.loggedIn, isTrue);
    expect(find.byType(HomeScreen), findsOneWidget);
    await session.clear();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await open(tester, fail: true);
    await tester.pumpAndSettle();
    await fill(tester);
    await tester.ensureVisible(find.widgetWithText(FilledButton, '로그인'));
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pumpAndSettle();
    expect(find.textContaining('로그인 정보가 올바르지'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      'a@example.test',
    );
  });
  testWidgets('회원가입은 비밀번호 확인 후 서버 가입을 호출하고 홈으로 이동한다', (tester) async {
    final requests = <String>[];
    final session = await open(tester, requests: requests);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('회원가입'));
    await tester.tap(find.text('회원가입'));
    await tester.pumpAndSettle();
    await fill(tester, signup: true, confirmation: 'different');
    await tester.ensureVisible(find.text('가입하기'));
    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();
    expect(find.text('비밀번호가 일치하지 않아요.'), findsOneWidget);
    expect(requests, isEmpty);
    await tester.enterText(find.byType(TextFormField).at(2), 'abcdefgh');
    await tester.ensureVisible(find.text('가입하기'));
    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();
    expect(requests, contains('/api/v1/auth/register'));
    expect(session.loggedIn, isTrue);
    expect(find.byType(SignUpScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('세션 복원 중에는 로그인 깜빡임 없이 기다리고 유효 세션은 홈으로 이동한다', (tester) async {
    final storage = DeferredStorage();
    await open(tester, storage: storage, restore: true);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    storage.ready.complete(
      jsonEncode({
        'accessToken': 'a',
        'refreshToken': 'r',
        'refreshExpiresAt': DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String(),
        'userId': 'a',
        'email': 'a@example.test',
      }),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });
  testWidgets('작은 화면·확대 글자·키보드에서도 가입 화면이 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('회원가입'));
    await tester.tap(find.text('회원가입'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('가입하기'));
    expect(tester.takeException(), isNull);
  });
  testWidgets('로그인 처리 중에는 대비가 있는 진행 표시와 중복 요청 방지를 제공한다', (tester) async {
    final response = Completer<http.Response>();
    final requests = <String>[];
    await open(tester, loginResponse: response, requests: requests);
    await tester.pumpAndSettle();
    await fill(tester);
    await tester.ensureVisible(find.widgetWithText(FilledButton, '로그인'));
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pump();
    final progress = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    final theme = Theme.of(tester.element(find.byType(FilledButton)));
    expect(progress.color, theme.colorScheme.onPrimary);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    expect(requests.where((path) => path.endsWith('/login')), hasLength(1));
    response.complete(http.Response('', 401));
    await tester.pumpAndSettle();
    expect(find.textContaining('로그인 정보가 올바르지'), findsOneWidget);
  });
}
