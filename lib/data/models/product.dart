enum PriceComparisonSite {
  danawa,
  enuri,
  naver;

  static PriceComparisonSite fromJson(Object? value) {
    return PriceComparisonSite.values.firstWhere(
      (site) => site.name == value,
      orElse: () => throw FormatException('지원하지 않는 가격비교 사이트입니다: $value'),
    );
  }
}

class Product {
  const Product({
    required this.id,
    required this.brand,
    required this.name,
    required this.category,
    required this.price,
    required this.priceCheckedAt,
    required this.priceComparisonSite,
    required this.priceComparisonUrl,
    required this.specs,
    this.imageAsset,
  });

  final String id;
  final String brand;
  final String name;
  final String category;
  final int price;
  final DateTime priceCheckedAt;
  final PriceComparisonSite priceComparisonSite;
  final Uri priceComparisonUrl;
  final String? imageAsset;
  final List<ProductSpecification> specs;

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawSpecs = json['specs'];
    if (rawSpecs is! List) {
      throw const FormatException('제품 specs는 배열이어야 합니다.');
    }

    return Product(
      id: json['id'] as String,
      brand: json['brand'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      price: json['price'] as int,
      priceCheckedAt: DateTime.parse(json['priceCheckedAt'] as String),
      priceComparisonSite: PriceComparisonSite.fromJson(
        json['priceComparisonSite'],
      ),
      priceComparisonUrl: Uri.parse(json['priceComparisonUrl'] as String),
      imageAsset: json['imageAsset'] as String?,
      specs: List<ProductSpecification>.unmodifiable(
        rawSpecs.map(
          (spec) => ProductSpecification.fromJson(
            Map<String, dynamic>.from(spec as Map),
          ),
        ),
      ),
    );
  }
}

class ProductSpecification {
  const ProductSpecification({
    required this.key,
    required this.label,
    required this.value,
    this.unit,
    this.sourceUrl,
    this.checkedAt,
  });

  final String key;
  final String label;
  final Object value;
  final String? unit;
  final Uri? sourceUrl;
  final DateTime? checkedAt;

  factory ProductSpecification.fromJson(Map<String, dynamic> json) {
    final value = json['value'];
    if (value is! String && value is! num && value is! bool) {
      throw const FormatException('사양 value는 문자열, 숫자 또는 참/거짓 값이어야 합니다.');
    }

    return ProductSpecification(
      key: json['key'] as String,
      label: json['label'] as String,
      value: value,
      unit: json['unit'] as String?,
      sourceUrl: json['sourceUrl'] == null
          ? null
          : Uri.parse(json['sourceUrl'] as String),
      checkedAt: json['checkedAt'] == null
          ? null
          : DateTime.parse(json['checkedAt'] as String),
    );
  }
}
