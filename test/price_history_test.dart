import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pickwise/data/models/price_history.dart';
import 'package:pickwise/data/models/product.dart';
import 'package:pickwise/data/services/pickwise_api.dart';
import 'package:pickwise/presentation/widgets/price_history_section.dart';

const _source =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _oldSource =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

Product _product({int version = 0}) => Product(
  id: 'history-test',
  brand: 'Test',
  name: 'Test',
  category: 'earbuds',
  price: 100000,
  priceCheckedAt: DateTime(2026, 11, 17),
  priceComparisonSite: PriceComparisonSite.danawa,
  priceComparisonUrl: Uri.parse('https://prod.danawa.com/info/?pcode=27250154'),
  specs: const [],
  version: version,
);

Map<String, dynamic> _body(
  http.Request request, {
  List<int> prices = const [150000, 100000],
  bool old = false,
}) => {
  'productId': 'history-test',
  'days': int.parse(request.url.queryParameters['days'] ?? '30'),
  'kind': request.url.queryParameters['kind'] ?? 'automatic',
  'asOf': '2026-11-17T00:00:00Z',
  'sourceKey': request.url.queryParameters['source'] ?? _source,
  'truncated': false,
  'total': prices.length,
  'sources': [
    {
      'key': _source,
      'site': 'danawa',
      'url': 'https://prod.danawa.com/info/?pcode=27250154',
      'current': true,
    },
    if (old)
      {
        'key': _oldSource,
        'site': 'danawa',
        'url': 'https://prod.danawa.com/info/?pcode=1',
        'current': false,
      },
  ],
  'points': [
    for (var i = 0; i < prices.length; i++)
      {
        'id': i + 1,
        'price': prices[i],
        'observedAt': DateTime.utc(2026, 11, 16, i).toIso8601String(),
        'checkedAt': '2026-11-15',
      },
  ],
};

http.Response _response(Map<String, dynamic> body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), 200);

Future<void> _pump(
  WidgetTester tester,
  PickwiseApi api, {
  int version = 0,
  double width = 390,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 1000),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: PriceHistorySection(
              product: _product(version: version),
              api: api,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('가격 통계는 실제 표시 기록만 사용하고 빈 이력에는 수치를 만들지 않는다', () {
    final request = http.Request(
      'GET',
      Uri.parse('https://test.invalid/?days=30'),
    );
    final history = PriceHistory.fromJson(
      _body(request, prices: [200000, 150000, 170000]),
    );
    expect(history.lowest, 150000);
    expect(history.highest, 200000);
    expect(history.change, -30000);
    final empty = PriceHistory.fromJson(_body(request, prices: []));
    expect(empty.lowest, isNull);
    expect(empty.highest, isNull);
    expect(empty.change, isNull);
  });

  test('0원·역순 이력은 정상 그래프로 읽지 않는다', () {
    final request = http.Request('GET', Uri.parse('https://test.invalid/'));
    expect(
      () => PriceHistory.fromJson(_body(request, prices: [0])),
      throwsFormatException,
    );
    final reversed = _body(request);
    reversed['points'] = (reversed['points'] as List).reversed.toList();
    expect(() => PriceHistory.fromJson(reversed), throwsFormatException);
  });

  testWidgets('기록이 없으면 0원 그래프를 만들지 않는다', (tester) async {
    final api = PickwiseApi(
      baseUrl: 'https://test.invalid',
      client: MockClient((r) async => _response(_body(r, prices: []))),
    );
    addTearDown(api.client.close);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester, api);
    expect(find.textContaining('자동 조회 기록이 아직 없어요'), findsOneWidget);
    expect(find.byKey(const ValueKey('price-history-chart')), findsNothing);
    expect(find.text('최저 0원'), findsNothing);
  });

  testWidgets('한 건·동일 가격도 그래프 계산 오류 없이 표시한다', (tester) async {
    var prices = [100000];
    final api = PickwiseApi(
      baseUrl: 'https://test.invalid',
      client: MockClient((r) async => _response(_body(r, prices: prices))),
    );
    addTearDown(api.client.close);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester, api);
    expect(find.textContaining('첫 기록이에요'), findsOneWidget);
    expect(tester.takeException(), isNull);
    prices = [100000, 100000];
    await _pump(tester, api, version: 1);
    expect(find.text('표시 기록의 시작 대비 변동 없음'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('기간과 확인 방식·이전 출처를 각각 서버에 요청한다', (tester) async {
    final requests = <Uri>[];
    final api = PickwiseApi(
      baseUrl: 'https://test.invalid',
      client: MockClient((r) async {
        requests.add(r.url);
        return _response(_body(r, old: true));
      }),
    );
    addTearDown(api.client.close);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester, api);
    await tester.tap(find.text('7일'));
    await tester.pumpAndSettle();
    expect(requests.last.queryParameters['days'], '7');
    await tester.tap(find.text('수동 입력'));
    await tester.pumpAndSettle();
    expect(requests.last.queryParameters['kind'], 'manual');
    expect(find.textContaining('그래프는 입력 시점 기준'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다나와 · 이전 출처 1').last);
    await tester.pumpAndSettle();
    expect(requests.last.queryParameters['source'], _oldSource);
    await tester.tap(find.text('90일'));
    await tester.pumpAndSettle();
    expect(requests.last.queryParameters['days'], '90');
    expect(requests.last.queryParameters['source'], isNull);
  });

  testWidgets('실패 후 재시도하며 갱신 실패 때 이전 응답을 구분한다', (tester) async {
    var fail = true;
    final api = PickwiseApi(
      baseUrl: 'https://test.invalid',
      client: MockClient(
        (r) async => fail ? http.Response('{}', 503) : _response(_body(r)),
      ),
    );
    addTearDown(api.client.close);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester, api);
    expect(find.textContaining('가격 이력을 불러오지 못했어요'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('가격 이력 다시 불러오기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('price-history-chart')), findsOneWidget);
    fail = true;
    await _pump(tester, api, version: 1);
    expect(find.textContaining('이전 응답'), findsOneWidget);
    expect(find.byKey(const ValueKey('price-history-chart')), findsOneWidget);
  });

  testWidgets('느리게 도착한 이전 기간 응답이 새 기간을 덮어쓰지 않는다', (tester) async {
    final delayed = Completer<http.Response>();
    http.Request? pending;
    final api = PickwiseApi(
      baseUrl: 'https://test.invalid',
      client: MockClient((r) async {
        if (r.url.queryParameters['days'] == '7') {
          pending = r;
          return delayed.future;
        }
        return _response(_body(r, prices: [90000]));
      }),
    );
    addTearDown(api.client.close);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester, api);
    await tester.tap(find.text('7일'));
    await tester.pump();
    await tester.tap(find.text('90일'));
    await tester.pumpAndSettle();
    delayed.complete(_response(_body(pending!, prices: [111111])));
    await tester.pumpAndSettle();
    expect(find.text('최저 90,000원'), findsOneWidget);
    expect(find.textContaining('111,111'), findsNothing);
  });

  testWidgets('320px·큰 글자에서 겹치지 않고 기록 목록으로도 확인한다', (tester) async {
    final api = PickwiseApi(
      baseUrl: 'https://test.invalid',
      client: MockClient((r) async => _response(_body(r, old: true))),
    );
    addTearDown(api.client.close);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester, api, width: 320, scale: 2);
    await tester.ensureVisible(find.text('최근 기록 보기'));
    await tester.tap(find.text('최근 기록 보기'));
    await tester.pumpAndSettle();
    expect(find.text('150,000원'), findsOneWidget);
    expect(find.text('100,000원'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
