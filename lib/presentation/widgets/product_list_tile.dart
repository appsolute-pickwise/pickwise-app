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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE1E8E3)),
        borderRadius: BorderRadius.circular(13),
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
              width: 72,
              height: 80,
              child: ProductArtwork(product: product),
            ),
          ),
          const SizedBox(width: 12),
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
                    padding: EdgeInsets.zero,
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
                      color: Colors.black,
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
    return OutlinedButton(
      key: ValueKey('compare-${product.id}'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF477966),
        backgroundColor: const Color(0xFFE5F0E9),
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
      child: Text(selected ? '✓ 비교에서 빼기' : '+ 비교에 담기'),
    );
  }
}
