import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/product_preferences.dart';
import '../providers/app_navigation_controller.dart';
import '../providers/product_provider.dart';
import '../widgets/pickwise_bottom_navigation.dart';
import '../widgets/product_list_tile.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    this.preferences = const ProductPreferences(),
  });

  final ProductPreferences preferences;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final candidates = preferences.recommend(provider.products);
    return Scaffold(
      appBar: AppBar(title: const Text('맞춤 추천')),
      bottomNavigationBar: const SafeArea(
        top: false,
        child: PickWiseBottomNavigation(selectedTab: PickWiseTab.home),
      ),
      body: provider.isLoading
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
          : candidates.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('조건에 맞는 제품이 없습니다.'),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('기준 다시 고르기'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(22),
              children: [
                const Text(
                  '선택한 조건에 가까운 제품',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  preferences.priorities.isEmpty
                      ? '조건에 맞는 제품을 낮은 가격순으로 보여드려요.'
                      : '선택한 사양을 고정 범위로 비교하고, 점수가 같으면 낮은 가격순으로 보여드려요.',
                ),
                const SizedBox(height: 24),
                for (
                  var index = 0;
                  index < candidates.take(3).length;
                  index++
                ) ...[
                  Text(
                    index == 0 ? '먼저 살펴볼 제품' : '함께 비교해 볼 제품',
                    style: const TextStyle(
                      color: Color(0xFF477966),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ProductListTile(product: candidates[index]),
                  for (final reason in preferences.reasons(candidates[index]))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• $reason'),
                    ),
                  const SizedBox(height: 16),
                ],
                FilledButton(
                  onPressed: provider.selectedCount == 0
                      ? null
                      : () {
                          context.read<AppNavigationController>().select(2);
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                        },
                  child: Text('선택한 ${provider.selectedCount}개 제품 비교하기'),
                ),
              ],
            ),
    );
  }
}
