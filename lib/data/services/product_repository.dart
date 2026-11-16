import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/services.dart';

import '../models/product.dart';
import 'pickwise_api.dart';

class ProductRepository {
  ProductRepository({PickwiseApi? api}) : api = api ?? PickwiseApi();
  final PickwiseApi api;
  bool usingCache = false;
  String? cachedAt;

  Future<List<Product>> loadProducts() async {
    usingCache = false;
    if (api.configured) {
      try {
        return await _loadRemote();
      } on FormatException {
        rethrow;
      } on TypeError {
        rethrow;
      } catch (error) {
        if (error is ApiException && error.status < 500) rethrow;
        if (error is! ApiException &&
            error is! TimeoutException &&
            error is! http.ClientException) {
          rethrow;
        }
        final storage = await SharedPreferences.getInstance();
        final raw = storage.getString("catalog:${api.baseUrl}");
        if (raw == null) rethrow;
        final cache = jsonDecode(raw) as Map;
        cachedAt = cache["at"] as String;
        final products = (cache["items"] as List)
            .map(
              (row) => Product.fromJson(Map<String, dynamic>.from(row as Map)),
            )
            .toList();
        usingCache = true;
        return products;
      }
    }
    throw const ApiException(0, '백엔드 주소가 비어 있어요.');
  }

  Future<List<Product>> _loadRemote() async {
    final rawItems = <dynamic>[];
    final items = <Product>[];
    var page = 0;
    while (true) {
      final response = await api.request(
        'GET',
        '/api/v1/products?page=$page&size=50',
      );
      final rows = response['items'] as List;
      rawItems.addAll(rows);
      items.addAll(
        rows.map(
          (row) => Product.fromJson(Map<String, dynamic>.from(row as Map)),
        ),
      );
      if (items.length >= (response['total'] as int)) break;
      if (rows.isEmpty) throw const FormatException('서버 페이지 정보가 올바르지 않아요.');
      page++;
    }
    final storage = await SharedPreferences.getInstance();
    cachedAt = DateTime.now().toUtc().toIso8601String();
    await storage.setString(
      'catalog:${api.baseUrl}',
      jsonEncode({'at': cachedAt, 'items': rawItems}),
    );
    return List.unmodifiable(items);
  }
}

class AssetProductRepository extends ProductRepository {
  @override
  Future<List<Product>> loadProducts() async {
    final jsonContent = await rootBundle.loadString(
      'assets/data/products.json',
    );
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
