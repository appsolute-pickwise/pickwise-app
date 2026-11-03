import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickwise/data/models/product.dart';
import 'package:pickwise/data/services/product_repository.dart';
import 'package:pickwise/presentation/providers/product_provider.dart';
import 'package:pickwise/presentation/screens/product_comparison_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pickwise/presentation/screens/price_check_screen.dart';
import 'package:pickwise/presentation/screens/product_detail_screen.dart';

const _earbudBattery = ProductSpecification(
  key: 'batteryHoursAncOn',
  label: '이어버드 재생 시간 (ANC 켬)',
  value: 8,
  unit: '시간',
);
const _caseBattery = ProductSpecification(
  key: 'maxBatteryHoursAncOn',
  label: '케이스 포함 재생 시간 (ANC 켬)',
  value: 24,
  unit: '시간',
);

Product _product({List<ProductSpecification> specs = const []}) => Product(
  id: 'layout-test-product',
  brand: 'Samsung',
  name: 'Galaxy Buds3 Pro',
  category: 'earbuds',
  price: 100000,
  priceCheckedAt: DateTime(2026, 10, 28),
  priceComparisonSite: PriceComparisonSite.danawa,
  priceComparisonUrl: Uri.parse('https://example.com/product'),
  specs: specs,
);

Future<void> _pumpScreen(
  WidgetTester tester,
  Widget screen, {
  double width = 390,
  double textScale = 1,
  double bottomPadding = 0,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(bottom: bottomPadding);
  tester.view.viewPadding = FakeViewPadding(bottom: bottomPadding);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: screen,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [320.0, 390.0]) {
    for (final scale in [1.5, 2.0]) {
      testWidgets('비교표 3개는 폭 $width·글자 $scale 배에서 넘치지 않는다', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final provider = ProductProvider();
        addTearDown(provider.dispose);
        await tester.runAsync(provider.loadProducts);
        for (final product in provider.products.take(3)) {
          provider.addToComparison(product.id);
        }
        await _pumpScreen(
          tester,
          ChangeNotifierProvider.value(
            value: provider,
            child: const ProductComparisonScreen(),
          ),
          width: width,
          textScale: scale,
        );
        expect(find.text('케이스 포함 · ANC 켬'), findsNWidgets(3));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('운영 제품 20개의 상세와 가격 화면이 320px에서 정상 표시된다', (tester) async {
    final products = await tester.runAsync(ProductRepository().loadProducts);
    expect(products, hasLength(20));
    for (final product in products!) {
      for (final screen in [
        ProductDetailScreen(product: product),
        PriceCheckScreen(product: product),
      ]) {
        await _pumpScreen(tester, screen, width: 320);
        expect(find.text(product.name), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: '${product.id}: ${screen.runtimeType}',
        );
      }
    }
  });

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.5, 2.0]) {
      testWidgets('가격 확인 화면은 폭 $width, 글자 배율 $scale 에서 넘치지 않는다', (
        tester,
      ) async {
        await _pumpScreen(
          tester,
          PriceCheckScreen(product: _product()),
          width: width,
          textScale: scale,
        );
        expect(find.text('다나와에서 가격 비교하기  ↗'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final detail in [true, false]) {
    testWidgets('${detail ? '상세' : '가격'} 화면의 하단 메뉴는 시스템 영역을 침범하지 않는다', (
      tester,
    ) async {
      final screen = detail
          ? ProductDetailScreen(product: _product())
          : PriceCheckScreen(product: _product());
      await _pumpScreen(tester, screen, bottomPadding: 48);
      for (final label in ['홈', '탐색', '비교']) {
        expect(
          tester.getBottomLeft(find.text(label)).dy,
          lessThanOrEqualTo(844 - 48),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('이어버드 배터리만 있으면 케이스 포함으로 안내하지 않는다', (tester) async {
    await _pumpScreen(
      tester,
      ProductDetailScreen(product: _product(specs: [_earbudBattery])),
    );
    expect(find.text('이어버드 배터리'), findsOneWidget);
    expect(find.text('최대 8시간 · 이어버드 · ANC 켬'), findsOneWidget);
    expect(find.text('이어버드 재생 시간 (ANC 켬)'), findsOneWidget);
    expect(find.textContaining('케이스 포함'), findsNothing);
  });

  testWidgets('두 배터리 사양이 있으면 케이스 포함 시간을 표시한다', (tester) async {
    await _pumpScreen(
      tester,
      ProductDetailScreen(
        product: _product(specs: [_earbudBattery, _caseBattery]),
      ),
    );
    expect(find.text('총 배터리'), findsOneWidget);
    expect(find.text('최대 24시간 · 케이스 포함 · ANC 켬'), findsOneWidget);
    expect(find.text('케이스 포함 재생 시간 (ANC 켬)'), findsOneWidget);
  });

  testWidgets('배터리 사양이 없으면 숫자를 만들지 않고 정보 없음으로 표시한다', (tester) async {
    await _pumpScreen(tester, ProductDetailScreen(product: _product()));
    expect(find.text('배터리 정보 없음'), findsOneWidget);
    expect(find.text('배터리'), findsOneWidget);
    expect(find.text('재생 시간'), findsOneWidget);
    expect(find.textContaining('최대 '), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ANC 미지원 제품은 일반 재생 시간으로 표시한다', (tester) async {
    await _pumpScreen(
      tester,
      ProductDetailScreen(
        product: _product(
          specs: const [
            ProductSpecification(key: 'anc', label: 'ANC', value: false),
            ProductSpecification(
              key: 'maxBatteryHours',
              label: '케이스 포함 재생 시간 (일반 재생)',
              value: 30,
              unit: '시간',
            ),
          ],
        ),
      ),
      width: 320,
    );
    expect(find.text('최대 30시간 · 케이스 포함 · 일반 재생'), findsOneWidget);
    expect(find.textContaining('ANC 켬'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
