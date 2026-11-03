import 'package:pickwise/data/models/product.dart';

Product product(
  String id, {
  double battery = 8,
  double? weight = 5,
  bool? anc = true,
  int price = 100000,
  bool normal = false,
}) => Product(
  id: id,
  brand: '테스트',
  name: id,
  category: 'earbuds',
  price: price,
  priceCheckedAt: DateTime(2026, 11, 3),
  priceComparisonSite: PriceComparisonSite.danawa,
  priceComparisonUrl: Uri.parse('https://example.com/$id'),
  specs: [
    ProductSpecification(
      key: normal ? 'batteryHours' : 'batteryHoursAncOn',
      label: '이어버드 재생 시간',
      value: battery,
      unit: '시간',
    ),
    if (weight != null)
      ProductSpecification(
        key: 'weight',
        label: '한 쪽 무게',
        value: weight,
        unit: 'g',
      ),
    if (anc != null) ProductSpecification(key: 'anc', label: 'ANC', value: anc),
  ],
);
