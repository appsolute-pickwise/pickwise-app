import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/product.dart';

import '../providers/session_provider.dart';

import '../providers/app_navigation_controller.dart';
import '../providers/product_provider.dart';
import '../widgets/product_artwork.dart';
import '../widgets/auth_page_layout.dart';
import '../widgets/product_formatters.dart';
import 'liking_screen.dart';
import 'product_detail_screen.dart';
import 'my_page_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    if (provider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (provider.hasLoadError) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(provider.loadErrorMessage),
              ElevatedButton(
                onPressed: provider.loadProducts,
                child: const Text('다시 불러오기'),
              ),
            ],
          ),
        ),
      );
    }
    if (provider.products.isEmpty) {
      return const Scaffold(body: Center(child: Text('비교할 제품이 없습니다.')));
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: const PickWiseAuthLogo(width: 176),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final navigation = context.read<AppNavigationController?>();
                    if (navigation != null) {
                      navigation.select(3);
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const MyPageScreen(),
                        ),
                      );
                    }
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      context.watch<SessionProvider?>()?.email ?? '로그인 · 회원가입',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              '내게 맞는\n선택을 쉽게.',
              style: TextStyle(
                fontSize: 32,
                height: 1.2,
                letterSpacing: -1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '필요한 사양만 골라 제품을 비교해요.',
              style: TextStyle(
                color: Color(0xFF657181),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              readOnly: true,
              onTap: () => context.read<AppNavigationController>().select(1),
              decoration: const InputDecoration(
                hintText: '모델명이나 브랜드를 검색해요',
                prefixIcon: Icon(Icons.search_rounded, size: 22),
                suffixIcon: Icon(Icons.arrow_forward_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 24),
            Material(
              color: const Color(0xFFE5F0E9),
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const LikingScreen()),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 22,
                            color: Color(0xFF477966),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '내 기준으로 비교 시작',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '배터리, 무게, ANC, 방수 중 중요한 것부터.',
                        style: TextStyle(fontSize: 13, height: 1.5),
                      ),
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Expanded(
                            child: Text(
                              '기준 선택하기 →',
                              style: TextStyle(
                                color: Color(0xFF477966),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '제품부터 둘러보기',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.5,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      context.read<AppNavigationController>().select(1),
                  child: const Text('전체 보기'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              key: const ValueKey('home-product-carousel'),
              scrollDirection: Axis.horizontal,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < provider.products.length; i++) ...[
                      if (i > 0) const SizedBox(width: 14),
                      _ProductCard(product: provider.products[i]),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 194,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE1E8E3)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProductDetailScreen(product: product),
            ),
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 272),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 128,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: ProductArtwork(product: product),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  product.brand,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF657181),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${formatPrice(product.price)}원',
                  style: const TextStyle(
                    color: Color(0xFF477966),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
