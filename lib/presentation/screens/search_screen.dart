import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/product_provider.dart';
import '../widgets/product_list_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _filter = '전체';
  String _query = '';
  String _sort = '기본순';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final query = _query.trim().toLowerCase();
    final products = provider.products.where((product) {
      return (product.name.toLowerCase().contains(query) ||
              product.brand.toLowerCase().contains(query)) &&
          (_filter == '전체' || product.tags.contains(_filter));
    }).toList();
    if (_sort == '낮은 가격순') products.sort((a, b) => a.price.compareTo(b.price));
    if (_sort == '높은 가격순') products.sort((a, b) => b.price.compareTo(a.price));

    return Scaffold(
      appBar: AppBar(
        title: const Text('이어폰 둘러보기'),
        actions: [
          PopupMenuButton<String>(
            tooltip: '제품 정렬',
            initialValue: _sort,
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (_) => ['기본순', '낮은 가격순', '높은 가격순']
                .map((label) => PopupMenuItem(value: label, child: Text(label)))
                .toList(),
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: '무선 이어폰, 브랜드 검색',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['전체', '통학', '운동', '업무', '노캔']
                      .map(
                        (label) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: _filter == label,
                            selectedColor: const Color(0xFFE5F0E9),
                            onSelected: (_) => setState(() => _filter = label),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${products.length}개 이어폰 후보',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : provider.hasLoadError
                    ? Center(
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
                      )
                    : products.isEmpty
                    ? const Center(child: Text('찾는 상품이 없습니다.'))
                    : ListView.builder(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: products.length,
                        itemBuilder: (_, index) =>
                            ProductListTile(product: products[index]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
