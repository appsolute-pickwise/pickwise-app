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
import 'package:pickwise/presentation/screens/delete_account_screen.dart';

import 'fixtures/session_storage.dart';

class _Fixture {
  final storage = MemorySessions();
  late SessionProvider session;
  int status = 422, deletions = 0;
  bool offline = false;
}

Future<_Fixture> _open(WidgetTester tester, {double scale = 1}) async {
  final f = _Fixture();
  final api = PickwiseApi(
    baseUrl: 'https://delete-test.invalid',
    client: MockClient((request) async {
      if (request.method == 'DELETE') {
        f.deletions++;
        expect(request.url.path, '/api/v1/me/account');
        expect(jsonDecode(request.body), {'currentPassword': 'abcdefgh'});
        if (f.offline) throw http.ClientException('offline');
        return http.Response('', f.status);
      }
      final Object body = request.url.path.endsWith('/auth/me')
          ? {'id': 'delete-user', 'email': 'test@example.test'}
          : request.url.path.endsWith('/preferences')
          ? {'preferences': <String, dynamic>{}}
          : {
              'accessToken': 'access',
              'refreshToken': 'refresh',
              'refreshExpiresAt': DateTime.now()
                  .add(const Duration(days: 30))
                  .toIso8601String(),
            };
      return http.Response(jsonEncode(body), 200);
    }),
  );
  final products = ProductProvider(repository: AssetProductRepository());
  f.session = SessionProvider(api: api, products: products, storage: f.storage);
  addTearDown(f.session.dispose);
  addTearDown(products.dispose);
  await f.session.login('test@example.test', 'abcdefgh');
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: f.session),
        ChangeNotifierProvider.value(value: products),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DeleteAccountScreen(),
                ),
              ),
              child: const Text('탈퇴 화면 열기'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('탈퇴 화면 열기'));
  await tester.pumpAndSettle();
  return f;
}

Future<void> _confirm(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField), 'abcdefgh');
  if (!tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value!) {
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(find.widgetWithText(FilledButton, '회원 탈퇴'));
  await tester.tap(find.widgetWithText(FilledButton, '회원 탈퇴'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('동의·비밀번호 검사와 최종 확인 취소는 삭제 요청을 보내지 않는다', (tester) async {
    final f = await _open(tester);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '회원 탈퇴'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '회원 탈퇴'));
    await tester.pumpAndSettle();
    expect(find.text('최소 8자 이상 입력해주세요.'), findsOneWidget);
    expect(f.deletions, 0);
    await _confirm(tester);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(f.deletions, 0);
    expect(f.session.loggedIn, isTrue);
  });
  testWidgets('비밀번호 오류는 계정을 유지하고 성공하면 본인 기기 정보만 지운다', (tester) async {
    final f = await _open(tester);
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      'selectionPreferences:delete-user',
      'defaultPreferences:delete-user',
      'comparison_product_ids:delete-user',
      'push-enabled:delete-user',
    ]) {
      await prefs.setString(key, 'owned');
    }
    const guest = '{"priorities":["무게"]}';
    await prefs.setString('selectionPreferences:guest', guest);
    await prefs.setString('defaultPreferences:other-user', 'other');
    await _confirm(tester);
    await tester.tap(find.text('탈퇴하기'));
    await tester.pumpAndSettle();
    expect(find.text('현재 비밀번호를 확인해주세요.'), findsOneWidget);
    expect(f.session.loggedIn, isTrue);
    expect(f.storage.value, isNotNull);
    f.status = 204;
    await _confirm(tester);
    await tester.tap(find.text('탈퇴하기'));
    await tester.pumpAndSettle();
    expect(f.session.loggedIn, isFalse);
    expect(f.storage.value, isNull);
    expect(
      prefs.getKeys().where((key) => key.endsWith(':delete-user')),
      isEmpty,
    );
    expect(prefs.getString('selectionPreferences:guest'), guest);
    expect(prefs.getString('defaultPreferences:other-user'), 'other');
    expect(find.byType(DeleteAccountScreen), findsNothing);
    expect(find.text('회원 탈퇴가 완료됐어요.'), findsOneWidget);
    expect(f.deletions, 2);
  });
  testWidgets('응답이 불명확하면 삭제를 재전송하거나 완료됐다고 표시하지 않는다', (tester) async {
    final f = await _open(tester)
      ..offline = true;
    await _confirm(tester);
    await tester.tap(find.text('탈퇴하기'));
    await tester.pumpAndSettle();
    expect(f.deletions, 1);
    expect(f.session.loggedIn, isTrue);
    expect(find.textContaining('계정 상태를 확인'), findsOneWidget);
    expect(find.text('회원 탈퇴가 완료됐어요.'), findsNothing);
  });
  testWidgets('최종 확인 도중 로그인이 바뀌면 삭제하지 않는다', (tester) async {
    final f = await _open(tester);
    await _confirm(tester);
    await f.session.clear();
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);
    await tester.tap(find.text('탈퇴하기'));
    await tester.pumpAndSettle();
    expect(f.deletions, 0);
  });
  testWidgets('작은 화면과 큰 글자·키보드에서도 탈퇴 확인을 할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _open(tester, scale: 2);
    await _confirm(tester);
    expect(find.text('정말 탈퇴할까요?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
