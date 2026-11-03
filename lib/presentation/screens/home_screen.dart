import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_navigation_controller.dart';
import '../providers/product_provider.dart';
import '../widgets/product_artwork.dart';
import '../widgets/product_formatters.dart';
import 'liking_screen.dart';
import 'product_detail_screen.dart';

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
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Image.asset(
                'assets/images/logo/pickwiselogo.png',
                width: 300,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '내게 맞는\n선택을 쉽게.',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '필요한 사양만 골라 제품을 비교해요.',
              style: TextStyle(color: Color(0xFF657181), fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              readOnly: true,
              onTap: () => context.read<AppNavigationController>().select(1),
              decoration: InputDecoration(
                hintText: '모델명이나 브랜드를 검색해요',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.symmetric(vertical: 30),
              decoration: BoxDecoration(
                color: const Color(0xFFE5F0E9),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '내 기준으로 비교 시작',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '배터리, 무게, ANC, 방수 중 중요한 것부터.',
                    style: TextStyle(fontSize: 13),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LikingScreen(),
                      ),
                    ),
                    child: const Text(
                      '기준 선택하기 →',
                      style: TextStyle(color: Color(0xFF477966)),
                    ),
                  ),
                ],
              ),
            ),
            const Text(
              '제품부터 둘러보기',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: provider.products.length,
                separatorBuilder: (_, _) => const SizedBox(width: 15),
                itemBuilder: (context, index) {
                  final product = provider.products[index];
                  return InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProductDetailScreen(product: product),
                      ),
                    ),
                    child: Container(
                      width: 210,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE1E8E3)),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Center(
                              child: ProductArtwork(product: product),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${formatPrice(product.price)}원',
                            style: const TextStyle(
                              color: Color(0xFF477966),
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
