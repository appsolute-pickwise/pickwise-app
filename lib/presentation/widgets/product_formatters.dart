import '../../data/models/product.dart';

String formatPrice(int price) {
  return price.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
}

String formatDate(DateTime date) {
  return '${date.year}년 ${date.month}월 ${date.day}일';
}

String formatCompactDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}.$month.$day';
}

String formatSpecificationValue(ProductSpecification specification) {
  final value = specification.value;
  final formattedValue = value is bool ? (value ? '지원' : '미지원') : '$value';
  final unit = specification.unit;

  return unit == null ? formattedValue : '$formattedValue $unit';
}

String priceComparisonSiteLabel(PriceComparisonSite site) {
  return switch (site) {
    PriceComparisonSite.danawa => '다나와',
    PriceComparisonSite.enuri => '에누리',
    PriceComparisonSite.naver => '네이버 쇼핑',
  };
}
