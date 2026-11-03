import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_navigation_controller.dart';
import '../providers/product_provider.dart';
import '../widgets/pickwise_bottom_navigation.dart';
import 'home_screen.dart';
import 'product_comparison_screen.dart';
import 'search_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _navigationVisible = true;
  double _scrollDistance = 0;
  int _lastIndex = 0;
  int _lastSelectedCount = 0;

  bool _onScroll(ScrollUpdateNotification notification) {
    if (notification.depth != 0 ||
        notification.metrics.axis != Axis.vertical ||
        notification.dragDetails == null ||
        notification.metrics.outOfRange) {
      return false;
    }
    final delta = notification.scrollDelta ?? 0;
    if (delta == 0) return false;
    if (_scrollDistance.sign != delta.sign) _scrollDistance = 0;
    _scrollDistance += delta;
    final atTop = notification.metrics.pixels <= 0;
    if (atTop || _scrollDistance.abs() >= 24) {
      final visible = atTop || _scrollDistance < 0;
      if (visible != _navigationVisible) {
        setState(() => _navigationVisible = visible);
      }
      _scrollDistance = 0;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final navigation = context.watch<AppNavigationController>();
    final selectedCount = context.select<ProductProvider, int>(
      (provider) => provider.selectedCount,
    );
    if (_lastIndex != navigation.index || _lastSelectedCount != selectedCount) {
      _navigationVisible = true;
      _scrollDistance = 0;
      _lastIndex = navigation.index;
      _lastSelectedCount = selectedCount;
    }
    final visible =
        MediaQuery.viewInsetsOf(context).bottom == 0 &&
        (_navigationVisible || MediaQuery.accessibleNavigationOf(context));
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return PopScope(
      canPop: navigation.index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) navigation.select(0);
      },
      child: Scaffold(
        body: NotificationListener<ScrollUpdateNotification>(
          onNotification: _onScroll,
          child: IndexedStack(
            index: navigation.index,
            children: const [
              HomeScreen(),
              SearchScreen(),
              ProductComparisonScreen(showBottomNavigation: false),
            ],
          ),
        ),
        bottomNavigationBar: TweenAnimationBuilder<double>(
          tween: Tween(end: visible ? 1 : 0),
          duration: duration,
          curve: Curves.easeOutCubic,
          child: IgnorePointer(
            ignoring: !visible,
            child: ExcludeSemantics(
              excluding: !visible,
              child: PickWiseBottomNavigation(
                selectedTab: PickWiseTab.values[navigation.index],
              ),
            ),
          ),
          builder: (context, value, child) => ClipRect(
            key: const ValueKey('app-bottom-navigation'),
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: value,
              child: FractionalTranslation(
                translation: Offset(0, 1 - value),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
