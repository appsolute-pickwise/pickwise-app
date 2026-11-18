import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pickwise/data/models/price_history.dart';
import 'package:pickwise/data/services/pickwise_api.dart';

void main() {
  const url = String.fromEnvironment('LIVE_API_URL');
  TestWidgetsFlutterBinding.ensureInitialized();
  test('실제 Docker 가격 이력 API를 Flutter 모델로 읽는다', () async {
    HttpOverrides.global = null;
    final api = PickwiseApi(baseUrl: url);
    addTearDown(api.client.close);
    final raw = await api.request(
      'GET',
      '/api/v1/products/sony-wf-1000xm5/price-history?days=30&kind=automatic',
    );
    final history = PriceHistory.fromJson(
      Map<String, dynamic>.from(raw as Map),
    );
    expect(history.productId, 'sony-wf-1000xm5');
    expect(history.days, 30);
    expect(history.kind, 'automatic');
    expect(history.sources.any((source) => source.current), isTrue);
    for (final point in history.points) {
      expect(point.price, greaterThan(0));
      expect(point.observedAt.isAfter(history.asOf), isFalse);
    }
  }, skip: url.isEmpty ? 'LIVE_API_URL 설정 시 실제 서버에 읽기 전용 검증' : false);
}
