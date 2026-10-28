import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../data/models/product.dart';
import '../providers/product_provider.dart';
import '../widgets/pickwise_bottom_navigation.dart';
import '../widgets/product_artwork.dart';
import '../widgets/product_formatters.dart';
import 'price_check_screen.dart';
import 'product_detail_screen.dart';

class ProductComparisonScreen extends StatelessWidget {
  const ProductComparisonScreen({super.key});

  static const _ink = Color(0xFF191F28);
  static const _muted = Color(0xFF657181);
  static const _green = Color(0xFF165A4B);

  void _openDetail(BuildContext context, Product product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailScreen(product: product),
      ),
    );
  }

  void _openPrice(BuildContext context, Product product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PriceCheckScreen(product: product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          },
          icon: SvgPicture.asset('assets/images/figma/back.svg'),
        ),
        title: const Text('제품 비교'),
      ),
      bottomNavigationBar: const PickWiseBottomNavigation(
        selectedTab: PickWiseTab.compare,
      ),
      body: Consumer<ProductProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.hasLoadError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(provider.loadErrorMessage),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: provider.loadProducts,
                    child: const Text('다시 불러오기'),
                  ),
                ],
              ),
            );
          }

          final products = provider.selectedProducts;
          if (products.isEmpty) {
            return const Center(child: Text('비교할 제품이 없습니다.'));
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '선택한 제품의 가격과 주요 사양을 비교해요.',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ProductHeaderRow(
                        products: products,
                        onOpenDetail: (product) =>
                            _openDetail(context, product),
                        onOpenPrice: (product) => _openPrice(context, product),
                      ),
                      if (products.length > 1) ...[
                        const SizedBox(height: 20),
                        _DifferenceSummary(products: products),
                      ],
                      const SizedBox(height: 26),
                      const Text(
                        '핵심 스펙 비교',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1, color: Color(0xFFE5E8EB)),
                      const SizedBox(height: 4),
                      _SpecificationTable(products: products),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 78,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: SizedBox.expand(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: () => _openDetail(context, products.first),
                      child: Text(
                        '${products.first.name} 상세 정보 보기  →',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DifferenceSummary extends StatelessWidget {
  const _DifferenceSummary({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final insights = _buildInsights(products);
    if (insights.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2EBE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '선택한 제품의 차이',
            style: TextStyle(
              color: Color(0xFF191F28),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          for (var index = 0; index < insights.length; index++) ...[
            if (index > 0) const SizedBox(height: 7),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.compare_arrows_rounded,
                    size: 14,
                    color: Color(0xFF165A4B),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    insights[index],
                    style: const TextStyle(
                      color: Color(0xFF3F4B57),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<String> _buildInsights(List<Product> products) {
    final insights = <String>[];

    final cheapest = products.reduce(
      (left, right) => left.price <= right.price ? left : right,
    );
    final mostExpensive = products.reduce(
      (left, right) => left.price >= right.price ? left : right,
    );
    final priceDifference = mostExpensive.price - cheapest.price;
    if (priceDifference > 0) {
      insights.add(
        '${_brandName(cheapest)}이(가) ${_brandName(mostExpensive)}보다 '
        '${formatPrice(priceDifference)}원 저렴해요.',
      );
    }

    final batteries = products
        .map(
          (product) => (
            product: product,
            value: _numericSpec(product, 'maxBatteryHoursAncOn'),
          ),
        )
        .where((entry) => entry.value != null)
        .toList(growable: false);
    if (batteries.length > 1) {
      final shortest = batteries.reduce(
        (left, right) => left.value! <= right.value! ? left : right,
      );
      final longest = batteries.reduce(
        (left, right) => left.value! >= right.value! ? left : right,
      );
      final difference = longest.value! - shortest.value!;
      if (difference > 0) {
        insights.add(
          '${_brandName(longest.product)}이(가) 케이스 포함 재생 시간이 '
          '${_brandName(shortest.product)}보다 ${_number(difference)}시간 길어요.',
        );
      }
    }

    final weights = products
        .map(
          (product) =>
              (product: product, value: _numericSpec(product, 'weight')),
        )
        .where((entry) => entry.value != null)
        .toList(growable: false);
    if (weights.length > 1) {
      final lightest = weights.reduce(
        (left, right) => left.value! <= right.value! ? left : right,
      );
      final heaviest = weights.reduce(
        (left, right) => left.value! >= right.value! ? left : right,
      );
      final difference = heaviest.value! - lightest.value!;
      if (difference > 0) {
        insights.add(
          '${_brandName(lightest.product)}이(가) 한 쪽 기준 '
          '${_brandName(heaviest.product)}보다 ${_number(difference)}g 가벼워요.',
        );
      }
    }

    return insights;
  }

  String _brandName(Product product) => product.brand;

  double? _numericSpec(Product product, String key) {
    for (final specification in product.specs) {
      if (specification.key == key && specification.value is num) {
        return (specification.value as num).toDouble();
      }
    }
    return null;
  }

  String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}

class _ProductHeaderRow extends StatelessWidget {
  const _ProductHeaderRow({
    required this.products,
    required this.onOpenDetail,
    required this.onOpenPrice,
  });

  final List<Product> products;
  final ValueChanged<Product> onOpenDetail;
  final ValueChanged<Product> onOpenPrice;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 82),
        for (var index = 0; index < products.length; index++)
          Expanded(
            child: _ProductHeader(
              product: products[index],
              darkArtwork: index == 0,
              onOpenDetail: () => onOpenDetail(products[index]),
              onOpenPrice: () => onOpenPrice(products[index]),
            ),
          ),
      ],
    );
  }
}

class _ProductHeader extends StatelessWidget {
  const _ProductHeader({
    required this.product,
    required this.darkArtwork,
    required this.onOpenDetail,
    required this.onOpenPrice,
  });

  final Product product;
  final bool darkArtwork;
  final VoidCallback onOpenDetail;
  final VoidCallback onOpenPrice;

  static const _green = Color(0xFF165A4B);
  static const _ink = Color(0xFF191F28);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Semantics(
          button: true,
          label: '${product.name} 상세 정보 보기',
          child: InkWell(
            onTap: onOpenDetail,
            borderRadius: BorderRadius.circular(14),
            child: Column(
              children: [
                Container(
                  width: 78,
                  height: 67,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: ProductArtwork(product: product, dark: darkArtwork),
                ),
                const SizedBox(height: 7),
                SizedBox(
                  height: 17,
                  child: Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '상세 보기',
                  style: TextStyle(
                    color: _green,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        GestureDetector(
          onTap: onOpenPrice,
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              '가격 보기',
              style: TextStyle(
                color: darkArtwork ? _green : _ink,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpecificationTable extends StatelessWidget {
  const _SpecificationTable({required this.products});

  final List<Product> products;

  static const _rows = <(String, String)>[
    ('가격', 'price'),
    ('배터리', 'battery'),
    ('무게', 'weight'),
    ('ANC', 'anc'),
    ('방수 등급', 'waterResistance'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < _rows.length; index++)
          _SpecificationRow(
            label: _rows[index].$1,
            keyName: _rows[index].$2,
            values: products
                .map((product) => _valueFor(product, _rows[index].$2))
                .toList(growable: false),
            detailValues: _rows[index].$2 == 'price'
                ? products
                      .map(
                        (product) => formatCompactDate(product.priceCheckedAt),
                      )
                      .toList(growable: false)
                : null,
            background: switch (index) {
              0 || 2 => const Color(0xFFF5F6F8),
              4 => const Color(0xFFE8F2EF),
              _ => Colors.white,
            },
          ),
      ],
    );
  }

  String _valueFor(Product product, String key) {
    if (key == 'price') return '${formatPrice(product.price)}원';
    final specificationKey = key == 'battery' ? 'maxBatteryHoursAncOn' : key;
    for (final specification in product.specs) {
      if (specification.key == specificationKey) {
        if (key == 'battery') {
          return '${specification.value}${specification.unit ?? ''}';
        }
        if (key == 'weight') {
          return '${specification.value}${specification.unit ?? ''} / 1개';
        }
        return formatSpecificationValue(specification);
      }
    }
    return '정보 없음';
  }
}

class _SpecificationRow extends StatelessWidget {
  const _SpecificationRow({
    required this.label,
    required this.keyName,
    required this.values,
    this.detailValues,
    required this.background,
  });

  final String label;
  final String keyName;
  final List<String> values;
  final List<String>? detailValues;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: detailValues == null ? 52 : 62,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF657181),
                    fontSize: 10,
                  ),
                ),
                if (detailValues != null) ...[
                  const SizedBox(height: 2),
                  const Text(
                    '확인일',
                    style: TextStyle(color: Color(0xFF8B95A1), fontSize: 8),
                  ),
                ],
              ],
            ),
          ),
          for (var index = 0; index < values.length; index++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: detailValues == null
                    ? _CellValue(value: values[index], keyName: keyName)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _CellValue(value: values[index], keyName: keyName),
                          const SizedBox(height: 2),
                          Text(
                            detailValues![index],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF8B95A1),
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CellValue extends StatelessWidget {
  const _CellValue({required this.value, required this.keyName});

  final String value;
  final String keyName;

  @override
  Widget build(BuildContext context) => Text(
    value,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textAlign: TextAlign.center,
    style: TextStyle(
      color: keyName == 'price'
          ? const Color(0xFF1B5FC7)
          : const Color(0xFF191F28),
      fontSize: 10,
      fontWeight: FontWeight.w600,
    ),
  );
}
