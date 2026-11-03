import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_navigation_controller.dart';
import '../widgets/pickwise_bottom_navigation.dart';
import 'home_screen.dart';
import 'product_comparison_screen.dart';
import 'search_screen.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final navigation = context.watch<AppNavigationController>();
    return PopScope(
      canPop: navigation.index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) navigation.select(0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: navigation.index,
          children: const [
            HomeScreen(),
            SearchScreen(),
            ProductComparisonScreen(showBottomNavigation: false),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: PickWiseBottomNavigation(
            selectedTab: PickWiseTab.values[navigation.index],
          ),
        ),
      ),
    );
  }
}
