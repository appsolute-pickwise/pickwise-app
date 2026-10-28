import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/product.dart';
import '../../data/services/product_repository.dart';

enum ProductSelectionResult {
  added,
  alreadySelected,
  maximumReached,
  differentCategory,
  productNotFound,
}

class ProductProvider extends ChangeNotifier {
  ProductProvider({ProductRepository? repository})
    : _repository = repository ?? ProductRepository();

  static const int maxComparisonProducts = 3;
  static const String _comparisonIdsKey = 'comparison_product_ids';

  final ProductRepository _repository;
  SharedPreferences? _preferences;
  List<Product> _products = const [];
  final List<String> _selectedProductIds = [];
  bool _isLoading = false;
  Object? _loadError;

  List<Product> get products => List.unmodifiable(_products);
  bool get isLoading => _isLoading;
  bool get hasLoadError => _loadError != null;
  String get loadErrorMessage => _loadError is FormatException
      ? (_loadError as FormatException).message
      : '제품 데이터를 불러오지 못했어요.';
  int get selectedCount => _selectedProductIds.length;

  List<Product> get selectedProducts => List.unmodifiable([
    for (final id in _selectedProductIds)
      for (final product in _products)
        if (product.id == id) product,
  ]);

  bool isSelected(String productId) => _selectedProductIds.contains(productId);

  Future<void> loadProducts() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();

    try {
      _products = await _repository.loadProducts();
      final preferences = await _getPreferences();
      final savedIds = preferences?.getStringList(_comparisonIdsKey);
      if (savedIds != null) {
        _restoreSelection(savedIds);
      } else {
        _restoreSelection(List<String>.of(_selectedProductIds));
        if (_selectedProductIds.isEmpty && _products.isNotEmpty) {
          final category = _products.first.category;
          _selectedProductIds.addAll(
            _products
                .where((product) => product.category == category)
                .take(maxComparisonProducts)
                .map((product) => product.id),
          );
        }
      }
    } catch (error, stackTrace) {
      _loadError = error;
      debugPrint('제품 데이터를 불러오지 못했습니다: $error\n$stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  ProductSelectionResult addToComparison(String productId) {
    Product? product;
    for (final item in _products) {
      if (item.id == productId) {
        product = item;
        break;
      }
    }
    if (product == null) return ProductSelectionResult.productNotFound;
    if (_selectedProductIds.contains(productId)) {
      return ProductSelectionResult.alreadySelected;
    }
    if (_selectedProductIds.length >= maxComparisonProducts) {
      return ProductSelectionResult.maximumReached;
    }

    final selected = selectedProducts;
    if (selected.isNotEmpty && selected.first.category != product.category) {
      return ProductSelectionResult.differentCategory;
    }

    _selectedProductIds.add(productId);
    _persistSelection();
    notifyListeners();
    return ProductSelectionResult.added;
  }

  void removeFromComparison(String productId) {
    if (_selectedProductIds.remove(productId)) {
      _persistSelection();
      notifyListeners();
    }
  }

  Future<SharedPreferences?> _getPreferences() async {
    if (_preferences != null) return _preferences;
    try {
      _preferences = await SharedPreferences.getInstance();
    } on MissingPluginException {
      return null;
    } catch (error, stackTrace) {
      debugPrint('비교 목록 저장소를 사용할 수 없습니다: $error\n$stackTrace');
      return null;
    }
    return _preferences;
  }

  void _restoreSelection(List<String> savedIds) {
    _selectedProductIds.clear();
    String? category;
    for (final id in savedIds) {
      final matches = _products.where((product) => product.id == id);
      if (matches.isEmpty) continue;
      if (_selectedProductIds.contains(id)) continue;
      final product = matches.first;
      category ??= product.category;
      if (product.category != category) continue;
      _selectedProductIds.add(id);
      if (_selectedProductIds.length == maxComparisonProducts) break;
    }
  }

  void _persistSelection() {
    final preferences = _preferences;
    if (preferences == null) return;
    unawaited(_writeSelection(preferences));
  }

  Future<void> _writeSelection(SharedPreferences preferences) async {
    try {
      await preferences.setStringList(
        _comparisonIdsKey,
        List<String>.of(_selectedProductIds),
      );
    } catch (error, stackTrace) {
      debugPrint('비교 목록을 저장하지 못했습니다: $error\n$stackTrace');
    }
  }
}
