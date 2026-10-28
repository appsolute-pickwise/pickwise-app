import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/product.dart';
import '../widgets/pickwise_bottom_navigation.dart';
import '../widgets/product_artwork.dart';
import '../widgets/product_formatters.dart';

class PriceCheckScreen extends StatelessWidget {
  const PriceCheckScreen({super.key, required this.product});

  final Product product;

  static const _ink = Color(0xFF191F28);
  static const _muted = Color(0xFF657181);
  static const _green = Color(0xFF165A4B);

  String get _priceSiteName =>
      priceComparisonSiteLabel(product.priceComparisonSite);

  Future<void> _openPriceComparison(BuildContext context) async {
    try {
      final opened = await launchUrl(
        product.priceComparisonUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && context.mounted) _showLinkError(context);
    } catch (_) {
      if (context.mounted) _showLinkError(context);
    }
  }

  void _showLinkError(BuildContext context) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$_priceSiteName 링크를 열지 못했어요.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: SvgPicture.asset('assets/images/figma/back.svg'),
        ),
        title: const Text('가격 확인하기'),
      ),
      bottomNavigationBar: const PickWiseBottomNavigation(
        selectedTab: PickWiseTab.explore,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 108,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6F8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: ProductArtwork(product: product),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${product.brand} · 무선 이어폰',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 11),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${formatDate(product.priceCheckedAt)} 확인 가격',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 9),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '가격은 $_priceSiteName에서 확인',
                          style: TextStyle(
                            color: _green,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    '$_priceSiteName에서 가격 확인',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(
                  width: 112,
                  child: Text(
                    '가격·배송 정보는 외부 페이지에서 확인',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: _muted, fontSize: 9, height: 1.2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Container(
              width: double.infinity,
              height: 194,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E8EB)),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '실시간 판매처 가격은 앱에서 합산하지 않아요.',
                    style: TextStyle(color: _ink, fontSize: 13),
                  ),
                  const SizedBox(height: 23),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
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
                      onPressed: () => _openPriceComparison(context),
                      child: Text('$_priceSiteName에서 가격 비교하기  ↗'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '가격·배송비·쿠폰은 $_priceSiteName에서 직접 확인해 주세요.',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
