import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/product.dart';

class ProductRepository {
  static const String _productsAssetPath = 'assets/data/products.json';

  Future<List<Product>> loadProducts() async {
    final jsonContent = await rootBundle.loadString(_productsAssetPath);
    final decodedJson = jsonDecode(jsonContent);

    if (decodedJson is! List) {
      throw const FormatException('제품 데이터는 JSON 배열이어야 합니다.');
    }

    return List<Product>.unmodifiable(
      decodedJson.map((item) {
        if (item is! Map) {
          throw const FormatException('제품 데이터 항목은 JSON 객체여야 합니다.');
        }

        return Product.fromJson(Map<String, dynamic>.from(item));
      }),
    );
  }
}
