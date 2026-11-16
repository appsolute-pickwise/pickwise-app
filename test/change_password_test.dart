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
import 'package:pickwise/presentation/screens/change_password_screen.dart';

import 'fixtures/session_storage.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('릴리스 주소는 공개 HTTPS만 허용한다', () {
    for (final value in [
      'http://example.com',
      'https://localhost',
      'https://name:secret@example.com',
      'https://example.com?key=secret',
    ]) {
      expect(
        () => PickwiseApi.validateDeploymentUrl(value),
        throwsArgumentError,
      );
    }
    expect(
      () => PickwiseApi.validateDeploymentUrl('https://api.example.com'),
      returnsNormally,
    );
  });
  testWidgets('잘못된 현재 비밀번호는 세션을 유지하고 성공하면 세션을 정리한다', (tester) async {
    var reject = true, changes = 0;
    final api = PickwiseApi(
      baseUrl: 'https://example.test',
      client: MockClient((r) async {
        if (r.url.path.endsWith('/password')) {
          changes++;
          return http.Response('', reject ? 422 : 204);
        }
        final data = r.url.path.endsWith('/login')
            ? {'accessToken': 'a', 'refreshToken': 'r'}
            : r.url.path.endsWith('/auth/me')
            ? {'id': 'a', 'email': 'a@example.test'}
            : {'preferences': {}};
        return http.Response(jsonEncode(data), 200);
      }),
    );
    final p = ProductProvider(repository: AssetProductRepository()),
        storage = MemorySessions();
    final session = SessionProvider(api: api, products: p, storage: storage);
    addTearDown(session.dispose);
    addTearDown(p.dispose);
    await session.login('a@example.test', 'abcdefgh');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: p),
          ChangeNotifierProvider.value(value: session),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const ChangePasswordScreen(),
                  ),
                ),
                child: const Text('변경 화면'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('변경 화면'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.enterText(
        find.byType(TextFormField).at(i),
        i == 0 ? 'abcdefgh' : '12345678',
      );
    }
    await tester.ensureVisible(find.widgetWithText(FilledButton, '비밀번호 변경'));
    await tester.tap(find.widgetWithText(FilledButton, '비밀번호 변경'));
    await tester.pumpAndSettle();
    expect(find.text('현재 비밀번호를 확인해주세요.'), findsOneWidget);
    expect(session.loggedIn, isTrue);
    expect(changes, 1);
    reject = false;
    await tester.tap(find.widgetWithText(FilledButton, '비밀번호 변경'));
    await tester.pumpAndSettle();
    expect(session.loggedIn, isFalse);
    expect(storage.value, isNull);
    expect(find.byType(ChangePasswordScreen), findsNothing);
  });
}
