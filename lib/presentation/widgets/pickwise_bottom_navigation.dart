import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_navigation_controller.dart';

enum PickWiseTab { home, explore, compare, my }

class PickWiseBottomNavigation extends StatelessWidget {
  const PickWiseBottomNavigation({
    super.key,
    required this.selectedTab,
    this.scrolled = true,
  });

  final PickWiseTab selectedTab;
  final bool scrolled;
  static const compactHeight = 56.0;

  static const _green = Color(0xFF165A4B);
  static const _muted = Color(0xFF657181);

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }
    final labelHeight = MediaQuery.textScalerOf(context).scale(11);
    final height = compactHeight + math.max(0, labelHeight - 11);
    final navigation = context.watch<AppNavigationController?>();
    final activeTab = navigation == null
        ? selectedTab
        : PickWiseTab.values[navigation.index];
    void select(PickWiseTab tab) {
      FocusManager.instance.primaryFocus?.unfocus();
      navigation?.select(tab.index);
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    return AnimatedContainer(
      key: const ValueKey('bottom-navigation-surface'),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 160),
      foregroundDecoration: BoxDecoration(
        border: Border(
          top: scrolled
              ? const BorderSide(color: Color(0xFFE5E8EB))
              : BorderSide.none,
        ),
      ),
      child: NavigationBar(
        height: height,
        animationDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        selectedIndex: activeTab.index,
        onDestinationSelected: navigation == null
            ? null
            : (index) => select(PickWiseTab.values[index]),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: const Color(0xFFE5F0E9),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? _green : _muted,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        destinations: [
          NavigationDestination(
            label: '홈',
            icon: const Icon(Icons.home_outlined, color: _muted, size: 24),
            selectedIcon: const Icon(
              Icons.home_rounded,
              color: _green,
              size: 24,
            ),
          ),
          NavigationDestination(
            label: '탐색',
            icon: const Icon(Icons.search_rounded, color: _muted, size: 24),
            selectedIcon: const Icon(
              Icons.search_rounded,
              color: _green,
              size: 24,
            ),
          ),
          const NavigationDestination(
            label: '비교',
            icon: Icon(Icons.view_column_outlined, color: _muted, size: 24),
            selectedIcon: Icon(
              Icons.view_column_rounded,
              color: _green,
              size: 24,
            ),
          ),
          const NavigationDestination(
            label: '마이',
            icon: Icon(Icons.person_outline_rounded, color: _muted, size: 24),
            selectedIcon: Icon(Icons.person_rounded, color: _green, size: 24),
          ),
        ],
      ),
    );
  }
}
