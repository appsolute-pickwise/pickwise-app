import '../widgets/catalog_receipt.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../data/models/product.dart';
import '../../data/models/product_preferences.dart';
import '../providers/product_provider.dart';
import '../providers/app_navigation_controller.dart';
import '../widgets/pickwise_bottom_navigation.dart';
import '../widgets/product_artwork.dart';
import '../widgets/product_formatters.dart';
import 'price_check_screen.dart';
import 'product_detail_screen.dart';
import 'comparison_history_screen.dart';

class ProductComparisonScreen extends StatelessWidget {
  const ProductComparisonScreen({super.key, this.showBottomNavigation = true});

  final bool showBottomNavigation;

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
        leading: !showBottomNavigation
            ? null
            : IconButton(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                icon: SvgPicture.asset('assets/images/figma/back.svg'),
              ),
        title: const Text('제품 비교'),
        actions: [
          IconButton(
            tooltip: '저장한 비교',
            icon: const Icon(Icons.bookmark_border_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const ComparisonHistoryScreen(),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: !showBottomNavigation
          ? null
          : const PickWiseBottomNavigation(selectedTab: PickWiseTab.compare),
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
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.view_column_outlined,
                      size: 44,
                      color: _green,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '비교할 제품이 없습니다.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () =>
                          context.read<AppNavigationController?>()?.select(1),
                      child: const Text('제품 찾아보기'),
                    ),
                  ],
                ),
              ),
            );
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
                      const CatalogReceipt(),
                      const SizedBox(height: 16),
                      _ProductHeaderRow(
                        products: products,
                        onOpenDetail: (product) =>
                            _openDetail(context, product),
                        onOpenPrice: (product) => _openPrice(context, product),
                      ),
                      if (products.length > 1 ||
                          products.any(
                            (product) =>
                                !provider.selectionPreferences.matches(product),
                          )) ...[
                        const SizedBox(height: 20),
                        _DifferenceSummary(
                          products: products,
                          preferences: provider.selectionPreferences,
                        ),
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
                      _SpecificationTable(
                        products: products,
                        preferences: provider.selectionPreferences,
                      ),
                    ],
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
  const _DifferenceSummary({required this.products, required this.preferences});

  final List<Product> products;
  final ProductPreferences preferences;

  @override
  Widget build(BuildContext context) {
    final personal = preferences.comparisonInsights(products);
    final failed = products.where((p) => !preferences.matches(p));
    final insights = [
      for (final product in failed)
        '${product.name}: 현재 필수·선택 조건과 달라요 (${preferences.exclusionReasons(product).join(', ')}).',
      ...personal,
      ...<String>[].where((text) => personal.isEmpty || text.contains('저렴해요.')),
    ];
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
          Text(
            preferences.priorities.isEmpty ? '선택한 제품의 차이' : '내 기준으로 본 차이',
            style: const TextStyle(
              color: Color(0xFF191F28),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (preferences.priorities.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              preferences.priorities
                  .toSet()
                  .map((key) => '$key ${preferences.weightFor(key)}/5')
                  .join(' · '),
              style: const TextStyle(fontSize: 11, color: Color(0xFF657181)),
            ),
          ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Row(
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
      ),
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
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '상세 보기',
                  style: TextStyle(
                    color: _green,
                    fontSize: 11,
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
        TextButton(
          onPressed: () =>
              context.read<ProductProvider>().removeFromComparison(product.id),
          child: const Text('빼기', style: TextStyle(fontSize: 11)),
        ),
      ],
    );
  }
}

class _SpecificationTable extends StatefulWidget {
  const _SpecificationTable({
    required this.products,
    required this.preferences,
  });

  final List<Product> products;

  final ProductPreferences preferences;
  @override
  State<_SpecificationTable> createState() => _SpecificationTableState();
}

class _SpecificationTableState extends State<_SpecificationTable> {
  bool _expanded = false;
  List<Product> get products => widget.products;
  ProductPreferences get preferences => widget.preferences;
  static const _defaultRows = <(String, String)>[
    ('가격', 'price'),
    ('배터리', 'battery'),
    ('무게', 'weight'),
    ('ANC', 'anc'),
    ('방수 등급', 'waterResistance'),
  ];

  @override
  Widget build(BuildContext context) {
    final priorities = preferences.priorities.toSet().toList()
      ..sort(
        (a, b) => preferences.weightFor(b).compareTo(preferences.weightFor(a)),
      );
    final rows = priorities.isEmpty
        ? [..._defaultRows]
        : <(String, String)>[
            ('가격', 'price'),
            for (final p in priorities)
              _defaultRows.firstWhere(
                (r) => r.$1 == p || p == '방수' && r.$2 == 'waterResistance',
              ),
          ];
    final extras = <(String, String)>[
      for (final r in _defaultRows)
        if (!rows.any((a) => a.$2 == r.$2)) r,
    ];
    for (final product in products) {
      for (final spec in product.specs) {
        if (!rows.any((r) => r.$2 == spec.key) &&
            !extras.any((r) => r.$2 == spec.key) &&
            !(spec.key == 'weight' ||
                spec.key == 'anc' ||
                spec.key == 'waterResistance')) {
          extras.add((spec.label, spec.key));
        }
      }
    }
    final displayedRows = [...rows, if (_expanded) ...extras];
    return Column(
      children: [
        Text(
          '배터리 비교 기준 · ${preferences.batteryCondition == 'ancOn' ? 'ANC 켬' : '일반 재생'}',
        ),
        for (var index = 0; index < displayedRows.length; index++)
          _SpecificationRow(
            label: displayedRows[index].$1,
            keyName: displayedRows[index].$2,
            values: products
                .map((product) => _valueFor(product, displayedRows[index].$2))
                .toList(growable: false),
            detailValues: displayedRows[index].$2 == 'price'
                ? products
                      .map(
                        (product) => formatCompactDate(product.priceCheckedAt),
                      )
                      .toList(growable: false)
                : displayedRows[index].$2 == 'battery'
                ? products
                      .map((product) {
                        final battery = preferences.batteryFor(product);
                        return battery == null
                            ? ''
                            : '이어버드 · ${battery.playbackCondition}';
                      })
                      .toList(growable: false)
                : null,
            background: switch (index) {
              0 || 2 => const Color(0xFFF5F6F8),
              4 => const Color(0xFFE8F2EF),
              _ => Colors.white,
            },
          ),
        TextButton(
          onPressed: () => setState(() => _expanded = !_expanded),
          child: Text(_expanded ? '주요 사양만 보기' : '전체 사양 보기'),
        ),
      ],
    );
  }

  String _valueFor(Product product, String key) {
    if (key == 'price') return '${formatPrice(product.price)}원';
    if (key == 'battery') {
      final battery = preferences.batteryFor(product);
      return battery == null
          ? '정보 없음'
          : '${battery.value}${battery.unit ?? ''}';
    }
    final specificationKey = key;
    for (final specification in product.specs) {
      if (specification.key == specificationKey) {
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
      constraints: BoxConstraints(minHeight: detailValues == null ? 52 : 62),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                  Text(
                    keyName == 'price' ? '확인일' : '재생 조건',
                    style: const TextStyle(
                      color: Color(0xFF8B95A1),
                      fontSize: 8,
                    ),
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
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _CellValue(value: values[index], keyName: keyName),
                          const SizedBox(height: 2),
                          Text(
                            detailValues![index],
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
