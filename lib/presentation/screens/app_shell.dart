import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_navigation_controller.dart';
import '../providers/product_provider.dart';
import '../widgets/pickwise_bottom_navigation.dart';
import 'home_screen.dart';
import 'my_page_screen.dart';
import 'product_comparison_screen.dart';
import 'search_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scrolled = List.filled(PickWiseTab.values.length, false);

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final index = context.read<AppNavigationController>().index;
    final scrolled =
        notification.metrics.pixels > notification.metrics.minScrollExtent + 1;
    if (_scrolled[index] != scrolled) {
      setState(() => _scrolled[index] = scrolled);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final navigation = context.watch<AppNavigationController>();
    final products = context.watch<ProductProvider>();
    return PopScope(
      canPop: navigation.index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) navigation.select(0);
      },
      child: Scaffold(
        body: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: Column(
            children: [
              if (products.usingCache)
                SafeArea(
                  bottom: false,
                  child: ListTile(
                    title: const Text('연결 실패 · 마지막으로 받은 제품 정보예요.'),
                    subtitle: Text('데이터 수신 시점: ${products.cachedAt ?? ''}'),
                    trailing: TextButton(
                      onPressed: products.loadProducts,
                      child: const Text('재시도'),
                    ),
                  ),
                ),
              Expanded(
                child: IndexedStack(
                  index: navigation.index,
                  children: const [
                    HomeScreen(),
                    SearchScreen(),
                    ProductComparisonScreen(showBottomNavigation: false),
                    MyPageScreen(),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SizedBox(
          key: const ValueKey('app-bottom-navigation'),
          child: PickWiseBottomNavigation(
            selectedTab: PickWiseTab.values[navigation.index],
            scrolled: _scrolled[navigation.index],
          ),
        ),
      ),
    );
  }
}
