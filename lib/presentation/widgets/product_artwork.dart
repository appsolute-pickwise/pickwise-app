import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/models/product.dart';

class ProductArtwork extends StatelessWidget {
  const ProductArtwork({super.key, this.product, this.dark = true});

  final Product? product;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final imageAsset = product?.imageAsset;
    if (imageAsset != null) {
      return Image.asset(
        imageAsset,
        fit: BoxFit.contain,
        semanticLabel: '${product!.name} 제품 사진',
        errorBuilder: (context, error, stackTrace) => _placeholder(),
      );
    }

    return _placeholder();
  }

  Widget _placeholder() {
    return SvgPicture.asset(
      dark
          ? 'assets/images/figma/earbud_dark.svg'
          : 'assets/images/figma/earbud_light.svg',
    );
  }
}
