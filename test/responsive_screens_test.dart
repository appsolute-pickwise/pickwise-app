import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pickwise/data/models/product.dart';
import 'package:pickwise/main.dart';
import 'package:pickwise/data/models/product_preferences.dart';
import 'package:pickwise/data/services/product_repository.dart';
import 'package:pickwise/data/services/pickwise_api.dart';
import 'package:pickwise/presentation/providers/product_provider.dart';
import 'package:pickwise/presentation/providers/session_provider.dart';
import 'package:pickwise/presentation/providers/app_navigation_controller.dart';
import 'package:pickwise/presentation/screens/home_screen.dart';
import 'package:pickwise/presentation/screens/search_screen.dart';
import 'package:pickwise/presentation/screens/liking_screen.dart';
import 'package:pickwise/presentation/screens/result_screen.dart';
import 'package:pickwise/presentation/screens/product_comparison_screen.dart';
import 'package:pickwise/presentation/screens/product_detail_screen.dart';
import 'package:pickwise/presentation/screens/price_check_screen.dart';
import 'package:pickwise/presentation/screens/my_page_screen.dart';
import 'package:pickwise/presentation/screens/login_screen.dart';
import 'package:pickwise/presentation/screens/sign_up_screen.dart';
import 'package:pickwise/presentation/screens/change_password_screen.dart';
import 'package:pickwise/presentation/screens/comparison_history_screen.dart';

import 'fixtures/session_storage.dart';

class _CatalogRepository extends ProductRepository {
  _CatalogRepository(this.items, {this.fail = false});
  final List<Product> items;
  final bool fail;
  @override
  Future<List<Product>> loadProducts() async {
    if (fail) throw const ApiException(503, '서버 연결 실패');
    return items;
  }
}

Future<ThemeData> _readAppTheme(
  WidgetTester tester,
  ProductProvider products,
) async {
  FlutterSecureStorage.setMockInitialValues({});
  await tester.pumpWidget(
    ChangeNotifierProvider.value(value: products, child: const PickWiseApp()),
  );
  await tester.pumpAndSettle();
  final theme = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!;
  await tester.pumpWidget(const SizedBox.shrink());
  return theme;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Product> catalog;
  const preferences = ProductPreferences(
    priorities: ['배터리', '무게', 'ANC', '방수'],
    budget: '5만~15만원',
    requireAnc: true,
  );
  setUpAll(() async {
    catalog = await AssetProductRepository().loadProducts();
  });
  for (final scenario in [
    (320.0, 568.0, 2.0, 0.0),
    (320.0, 568.0, 1.0, 0.0),
    (390.0, 844.0, 1.0, 0.0),
    (390.0, 844.0, 2.0, 300.0),
    (844.0, 390.0, 1.5, 180.0),
    (768.0, 1024.0, 2.0, 0.0),
  ]) {
    for (final page in [
      'home',
      'search',
      'liking',
      'result',
      'compare',
      'detail',
      'price',
      'my',
      'login',
      'signup',
      'password',
      'history',
    ]) {
      testWidgets(
        '$page ${scenario.$1}x${scenario.$2} 글자 ${scenario.$3} 키보드 ${scenario.$4}',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = Size(scenario.$1, scenario.$2);
          tester.view.devicePixelRatio = 1;
          tester.view.viewInsets = FakeViewPadding(bottom: scenario.$4);
          final padding = scenario.$1 > scenario.$2
              ? const FakeViewPadding(left: 44, right: 44, bottom: 21)
              : const FakeViewPadding(top: 47, bottom: 34);
          tester.view.padding = padding;
          tester.view.viewPadding = padding;
          tester.platformDispatcher.textScaleFactorTestValue = scenario.$3;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          addTearDown(tester.view.resetPadding);
          addTearDown(tester.view.resetViewPadding);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final original = catalog.first;
          final long = Product(
            id: 'long-name',
            brand: '브랜드 이름이 아주 긴 제품 제조사',
            name: '모델 이름이 아주 긴 무선 이어폰 프로 스페셜 에디션 한정판',
            category: original.category,
            price: 1299999,
            priceCheckedAt: original.priceCheckedAt,
            priceComparisonSite: original.priceComparisonSite,
            priceComparisonUrl: original.priceComparisonUrl,
            specs: original.specs,
            imageAsset: original.imageAsset,
          );
          final products = ProductProvider(
            repository: _CatalogRepository([long, ...catalog]),
          );
          await products.loadProducts();
          final theme = await _readAppTheme(tester, products);
          final api = PickwiseApi(
            baseUrl: 'https://example.test',
            client: MockClient((r) async {
              final Object body = r.url.path.endsWith('/login')
                  ? {'accessToken': 'a', 'refreshToken': 'r'}
                  : r.url.path.endsWith('/auth/me')
                  ? {
                      'id': 'a',
                      'email': 'very-long-account-name-for-layout-verification@example.test',
                    }
                  : r.url.path.endsWith('/preferences')
                  ? {'preferences': preferences.toJson()}
                  : [
                      {
                        'id': 'record',
                        'title': '비교 이름이 아주 긴 출퇴근용 무선 이어폰 구매 후보 기록',
                        'version': 0,
                        'productIds': [long.id],
                        'preferences': preferences.toJson(),
                        'snapshot': null,
                      },
                    ];
              return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
            }),
          );
          final session = SessionProvider(
            api: api,
            products: products,
            storage: MemorySessions(),
          );
          addTearDown(products.dispose);
          addTearDown(session.dispose);
          await session.login('test@example.test', 'abcdefgh');
          products.restoreComparison([
            long.id,
            ...catalog.take(2).map((p) => p.id),
          ], preferences);
          final Widget screen = switch (page) {
            'home' => const HomeScreen(),
            'search' => const SearchScreen(),
            'liking' => const LikingScreen(),
            'result' => const ResultScreen(preferences: preferences),
            'compare' => const ProductComparisonScreen(),
            'detail' => ProductDetailScreen(product: long),
            'price' => PriceCheckScreen(product: long),
            'my' => const MyPageScreen(),
            'login' => const LoginScreen(),
            'signup' => const SignUpScreen(),
            'password' => const ChangePasswordScreen(),
            _ => const ComparisonHistoryScreen(),
          };
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: products),
                ChangeNotifierProvider.value(value: session),
                ChangeNotifierProvider(
                  create: (_) => AppNavigationController(),
                ),
              ],
              child: MaterialApp(theme: theme, home: screen),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (['login', 'signup', 'password'].contains(page)) {
            for (final element in find.text('최소 8자 이상 입력해주세요.').evaluate()) {
              expect(
                (element.renderObject! as RenderParagraph).didExceedMaxLines,
                isFalse,
              );
            }
            tester.state<FormState>(find.byType(Form)).validate();
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            for (final element in find.byType(RichText).evaluate()) {
              final paragraph = element.renderObject! as RenderParagraph;
              if (paragraph.text.toPlainText().contains('입력해주세요.') ||
                  paragraph.text.toPlainText().contains('확인해주세요.')) {
                expect(paragraph.didExceedMaxLines, isFalse);
              }
            }
          }
          final scroll = find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          );
          if (scroll.evaluate().isNotEmpty) {
            for (var i = 0; i < 5; i++) {
              await tester.drag(scroll.first, const Offset(0, -300));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
          }
          if (page == 'liking') {
            final dropdown = find.byType(DropdownButtonFormField<double>);
            await tester.ensureVisible(dropdown);
            await tester.tap(dropdown);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.tap(find.text('5g 이하').last);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          if (page == 'compare') {
            await tester.ensureVisible(find.text('전체 사양 보기'));
            await tester.tap(find.text('전체 사양 보기'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          if (page == 'history') {
            final title = find.text('비교 이름이 아주 긴 출퇴근용 무선 이어폰 구매 후보 기록');
            await tester.ensureVisible(title);
            await tester.tap(title);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }

  for (final home in [true, false]) {
    for (final fail in [true, false]) {
      testWidgets(
        '${home ? '홈' : '비교'} ${fail ? '연결 오류' : '빈 목록'}도 작은 가로 화면에서 스크롤한다',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = const Size(568, 320);
          tester.view.devicePixelRatio = 1;
          tester.view.viewInsets = const FakeViewPadding(bottom: 120);
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final products = ProductProvider(
            repository: _CatalogRepository([], fail: fail),
          );
          addTearDown(products.dispose);
          await products.loadProducts();
          final theme = await _readAppTheme(tester, products);
          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: products,
              child: MaterialApp(
                theme: theme,
                home: home
                    ? const HomeScreen()
                    : const ProductComparisonScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(fail ? '다시 불러오기' : '비교할 제품이 없습니다.'), findsOneWidget);
          if (!home && !fail) {
            await tester.ensureVisible(find.text('제품 찾아보기'));
            await tester.pumpAndSettle();
            expect(find.text('제품 찾아보기').hitTestable(), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
