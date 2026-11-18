import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/product.dart';
import '../../data/services/pickwise_api.dart';
import '../providers/product_provider.dart';
import '../providers/session_provider.dart';
import '../widgets/product_artwork.dart';
import '../widgets/product_formatters.dart';
import 'product_editor_screen.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  List<Product> _products = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  late final SessionProvider _session;
  late final int _epoch;

  @override
  void initState() {
    super.initState();
    _session = context.read<SessionProvider>();
    _epoch = _session.generation;
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!_session.isAdmin || _session.generation != _epoch) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = <Product>[];
      var page = 0;
      while (true) {
        final data = await _session.api.request(
          'GET',
          '/api/v1/products?size=50&page=$page',
        );
        final rows = data['items'] as List;
        products.addAll(
          rows.map(
            (row) => Product.fromJson(Map<String, dynamic>.from(row as Map)),
          ),
        );
        if (products.length >= (data['total'] as int)) break;
        if (rows.isEmpty) throw const FormatException('잘못된 페이지 정보');
        page++;
      }
      if (mounted && _session.generation == _epoch) {
        setState(() => _products = products);
      }
    } catch (error) {
      if (mounted && _session.generation == _epoch) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : '상품을 불러오지 못했어요. 연결을 확인해주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Product? product]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ProductEditorScreen(productId: product?.id, catalog: _products),
      ),
    );
    if (saved == true && mounted && _session.generation == _epoch) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('상품 정보를 저장했어요.')));
      unawaited(context.read<ProductProvider>().loadProducts());
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final allowed = session.isAdmin && session.generation == _epoch;
    final visible = _products
        .where(
          (p) => '${p.brand} ${p.name}'.toLowerCase().contains(
            _query.toLowerCase(),
          ),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('상품 관리')),
      floatingActionButton: allowed
          ? FloatingActionButton.extended(
              onPressed: _loading ? null : () => _edit(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('상품 등록'),
            )
          : null,
      body: !allowed
          ? const Center(child: Text('관리자 계정으로 로그인해주세요.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '브랜드·제품명 검색',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 20),
                  if (_loading) const LinearProgressIndicator(),
                  if (_error != null) ...[
                    Text(_error!),
                    TextButton(onPressed: _load, child: const Text('다시 불러오기')),
                  ],
                  if (!_loading && _error == null)
                    Text('${visible.length}개 상품'),
                  if (!_loading && visible.isEmpty && _error == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text('등록된 상품이 없거나 검색 결과가 없어요.'),
                    ),
                  for (final product in visible)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      leading: SizedBox(
                        width: 52,
                        height: 52,
                        child: ProductArtwork(product: product),
                      ),
                      title: Text('${product.brand} ${product.name}'),
                      subtitle: Text(
                        '${formatPrice(product.price)}원\n${formatPriceFreshness(product)}',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _loading ? null : () => _edit(product),
                    ),
                ],
              ),
            ),
    );
  }
}
