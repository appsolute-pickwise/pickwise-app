import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/product.dart';
import '../providers/product_provider.dart';
import '../screens/product_detail_screen.dart';
import 'product_artwork.dart';
import 'product_formatters.dart';

class ProductListTile extends StatelessWidget {
  const ProductListTile({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE1E8E3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProductDetailScreen(product: product),
              ),
            ),
            child: SizedBox(
              width: 88,
              height: 100,
              child: ProductArtwork(product: product),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.brand,
                  style: const TextStyle(
                    color: Color(0xFF657181),
                    fontSize: 12,
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProductDetailScreen(product: product),
                    ),
                  ),
                  child: Text(
                    product.name,
                    style: const TextStyle(
                      color: Color(0xFF191F28),
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${formatPrice(product.price)}원',
                  style: const TextStyle(
                    color: Color(0xFF477966),
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ComparisonButton(product: product),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ComparisonButton extends StatelessWidget {
  const ComparisonButton({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final selected = provider.isSelected(product.id);
    return OutlinedButton.icon(
      key: ValueKey('compare-${product.id}'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF477966),
        backgroundColor: const Color(0xFFE5F0E9),
        side: BorderSide.none,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () {
        if (selected) {
          provider.removeFromComparison(product.id);
          return;
        }
        final result = provider.addToComparison(product.id);
        final error = switch (result) {
          ProductSelectionResult.maximumReached => '제품은 최대 3개까지 비교할 수 있어요.',
          ProductSelectionResult.differentCategory => '같은 종류의 제품끼리 비교해 주세요.',
          ProductSelectionResult.productNotFound => '제품 정보를 찾을 수 없어요.',
          _ => null,
        };
        if (error != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error)));
        }
      },
      icon: Icon(selected ? Icons.check_rounded : Icons.add_rounded, size: 17),
      label: Text(selected ? '비교에서 빼기' : '비교에 담기'),
    );
  }
}
