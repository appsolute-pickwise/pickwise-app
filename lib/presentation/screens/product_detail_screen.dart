import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/product.dart';
import '../widgets/pickwise_bottom_navigation.dart';
import '../widgets/product_artwork.dart';
import '../widgets/product_formatters.dart';
import 'price_check_screen.dart';

class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({super.key, required this.product});

  final Product product;

  static const _ink = Color(0xFF191F28);
  static const _muted = Color(0xFF657181);
  static const _green = Color(0xFF165A4B);

  ProductSpecification? _specification(String key) {
    for (final specification in product.specs) {
      if (specification.key == key) return specification;
    }
    return null;
  }

  void _openPriceCheck(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PriceCheckScreen(product: product),
      ),
    );
  }

  Future<void> _openSpecificationSource(
    BuildContext context,
    ProductSpecification specification,
  ) async {
    final sourceUrl = specification.sourceUrl;
    if (sourceUrl == null) return;

    try {
      final opened = await launchUrl(
        sourceUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && context.mounted) {
        _showSourceError(context, specification.label);
      }
    } catch (_) {
      if (context.mounted) _showSourceError(context, specification.label);
    }
  }

  void _showSourceError(BuildContext context, String label) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$label 출처를 열지 못했어요.')));
  }

  @override
  Widget build(BuildContext context) {
    final battery =
        _specification('maxBatteryHoursAncOn') ??
        _specification('batteryHoursAncOn');
    final weight = _specification('weight');
    final waterResistance = _specification('waterResistance');
    final anc = _specification('anc');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: SvgPicture.asset('assets/images/figma/back.svg'),
        ),
        title: const Text('제품 상세'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 15, 24, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 170,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ProductArtwork(product: product),
            ),
            const SizedBox(height: 12),
            Text(
              product.brand,
              style: const TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              product.name,
              style: const TextStyle(
                color: _ink,
                fontSize: 23,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text('가격 정보', style: TextStyle(color: _muted, fontSize: 12)),
            const SizedBox(height: 3),
            Text(
              '${formatPrice(product.price)}원',
              style: const TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${priceComparisonSiteLabel(product.priceComparisonSite)} 기준 · ${formatDate(product.priceCheckedAt)} 확인',
              style: const TextStyle(color: _muted, fontSize: 10),
            ),
            const SizedBox(height: 29),
            Row(
              children: [
                _SpecCard(
                  value: battery == null
                      ? '정보 없음'
                      : '최대 ${battery.value}${battery.unit ?? ''}',
                  label: '총 배터리',
                  highlighted: true,
                ),
                const SizedBox(width: 8),
                _SpecCard(
                  value: weight == null
                      ? '정보 없음'
                      : '${weight.value}${weight.unit ?? ''} / 1개',
                  label: '이어버드 무게',
                ),
                const SizedBox(width: 8),
                _SpecCard(
                  value: waterResistance == null
                      ? '정보 없음'
                      : formatSpecificationValue(waterResistance),
                  label: '방수 등급',
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              '알아두면 좋은 점',
              style: TextStyle(
                color: _ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              height: 92,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E8EB)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _FeatureLine(
                    text: anc == null
                        ? '노이즈 캔슬링 정보 없음'
                        : 'ANC ${formatSpecificationValue(anc)} · 공식 스펙 기준',
                    icon: Icons.check,
                  ),
                  const SizedBox(height: 8),
                  _FeatureLine(
                    text: battery == null
                        ? '배터리 정보 없음'
                        : '최대 ${battery.value}${battery.unit ?? ''} · 케이스 포함 · ANC 켬',
                    icon: Icons.battery_5_bar_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              '사양 출처',
              style: TextStyle(
                color: _ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E8EB)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _SpecificationSourceRow(
                    label: '케이스 포함 재생 시간 · ANC 켬',
                    specification: battery,
                    onTap: battery == null
                        ? null
                        : () => _openSpecificationSource(context, battery),
                  ),
                  const _SourceDivider(),
                  _SpecificationSourceRow(
                    label: '이어버드 무게 · 한 쪽',
                    specification: weight,
                    onTap: weight == null
                        ? null
                        : () => _openSpecificationSource(context, weight),
                  ),
                  const _SourceDivider(),
                  _SpecificationSourceRow(
                    label: '노이즈 캔슬링',
                    specification: anc,
                    onTap: anc == null
                        ? null
                        : () => _openSpecificationSource(context, anc),
                  ),
                  const _SourceDivider(),
                  _SpecificationSourceRow(
                    label: '방수 등급',
                    specification: waterResistance,
                    onTap: waterResistance == null
                        ? null
                        : () => _openSpecificationSource(
                            context,
                            waterResistance,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () => _openPriceCheck(context),
                  child: Text(
                    '현재 가격은 ${priceComparisonSiteLabel(product.priceComparisonSite)}에서 보기  →',
                  ),
                ),
              ),
            ),
          ),
          const PickWiseBottomNavigation(selectedTab: PickWiseTab.explore),
        ],
      ),
    );
  }
}

class _SpecCard extends StatelessWidget {
  const _SpecCard({
    required this.value,
    required this.label,
    this.highlighted = false,
  });

  final String value;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E8EB)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: highlighted
                      ? const Color(0xFF1B5FC7)
                      : const Color(0xFF191F28),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF657181), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF16803D), size: 16),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF303B4A), fontSize: 10),
          ),
        ),
      ],
    );
  }
}

class _SpecificationSourceRow extends StatelessWidget {
  const _SpecificationSourceRow({
    required this.label,
    required this.specification,
    required this.onTap,
  });

  final String label;
  final ProductSpecification? specification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final checkedAt = specification?.checkedAt;
    final dateLabel = checkedAt == null
        ? '확인일 없음'
        : '확인 ${checkedAt.year}.${checkedAt.month.toString().padLeft(2, '0')}.${checkedAt.day.toString().padLeft(2, '0')}';

    return Semantics(
      button: onTap != null,
      label: '$label, $dateLabel, 출처 열기',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF191F28),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        color: Color(0xFF657181),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new,
                color: onTap == null
                    ? const Color(0xFFB8C0CC)
                    : const Color(0xFF165A4B),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceDivider extends StatelessWidget {
  const _SourceDivider();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 14),
    child: Divider(height: 1, color: Color(0xFFE5E8EB)),
  );
}
