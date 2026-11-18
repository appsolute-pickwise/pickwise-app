class PriceHistoryPoint {
  const PriceHistoryPoint({
    required this.price,
    required this.observedAt,
    required this.checkedAt,
  });
  final int price;
  final DateTime observedAt;
  final DateTime checkedAt;

  factory PriceHistoryPoint.fromJson(Map<String, dynamic> json) {
    final price = json['price'] as int;
    if (price <= 0) throw const FormatException('가격 이력은 양수여야 합니다.');
    return PriceHistoryPoint(
      price: price,
      observedAt: DateTime.parse(json['observedAt'] as String),
      checkedAt: DateTime.parse(json['checkedAt'] as String),
    );
  }
}

class PriceHistorySource {
  const PriceHistorySource({
    required this.key,
    required this.site,
    required this.url,
    required this.current,
  });
  final String key, site;
  final Uri url;
  final bool current;

  factory PriceHistorySource.fromJson(Map<String, dynamic> json) =>
      PriceHistorySource(
        key: json['key'] as String,
        site: json['site'] as String,
        url: Uri.parse(json['url'] as String),
        current: json['current'] as bool,
      );
}

class PriceHistory {
  const PriceHistory({
    required this.productId,
    required this.days,
    required this.kind,
    required this.asOf,
    required this.sourceKey,
    required this.sources,
    required this.points,
    required this.truncated,
  });
  final String productId, kind, sourceKey;
  final int days;
  final DateTime asOf;
  final List<PriceHistorySource> sources;
  final List<PriceHistoryPoint> points;
  final bool truncated;

  int? get lowest => points.isEmpty
      ? null
      : points.map((point) => point.price).reduce((a, b) => a < b ? a : b);
  int? get highest => points.isEmpty
      ? null
      : points.map((point) => point.price).reduce((a, b) => a > b ? a : b);
  int? get change =>
      points.length < 2 ? null : points.last.price - points.first.price;

  factory PriceHistory.fromJson(Map<String, dynamic> json) {
    final points = List<PriceHistoryPoint>.unmodifiable(
      (json['points'] as List).map(
        (point) =>
            PriceHistoryPoint.fromJson(Map<String, dynamic>.from(point as Map)),
      ),
    );
    for (var i = 1; i < points.length; i++) {
      if (points[i].observedAt.isBefore(points[i - 1].observedAt)) {
        throw const FormatException('가격 이력이 시간순이 아닙니다.');
      }
    }
    return PriceHistory(
      productId: json['productId'] as String,
      days: json['days'] as int,
      kind: json['kind'] as String,
      asOf: DateTime.parse(json['asOf'] as String),
      sourceKey: json['sourceKey'] as String,
      sources: List.unmodifiable(
        (json['sources'] as List).map(
          (source) => PriceHistorySource.fromJson(
            Map<String, dynamic>.from(source as Map),
          ),
        ),
      ),
      points: points,
      truncated: json['truncated'] as bool,
    );
  }
}
