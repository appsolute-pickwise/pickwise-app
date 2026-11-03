import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../providers/app_navigation_controller.dart';

enum PickWiseTab { home, explore, compare }

class PickWiseBottomNavigation extends StatelessWidget {
  const PickWiseBottomNavigation({super.key, required this.selectedTab});

  final PickWiseTab selectedTab;

  static const _green = Color(0xFF165A4B);
  static const _muted = Color(0xFF657181);

  @override
  Widget build(BuildContext context) {
    final navigation = context.watch<AppNavigationController?>();
    final activeTab = navigation == null
        ? selectedTab
        : PickWiseTab.values[navigation.index];
    void select(PickWiseTab tab) {
      FocusManager.instance.primaryFocus?.unfocus();
      navigation?.select(tab.index);
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    Widget svgIcon(String asset, Color color) => SvgPicture.asset(
      asset,
      width: 22,
      height: 22,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );

    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE5E8EB))),
      ),
      child: NavigationBar(
        height: 64,
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
            icon: svgIcon('assets/images/figma/home.svg', _muted),
            selectedIcon: svgIcon('assets/images/figma/home.svg', _green),
          ),
          NavigationDestination(
            label: '탐색',
            icon: svgIcon('assets/images/figma/search.svg', _muted),
            selectedIcon: svgIcon('assets/images/figma/search.svg', _green),
          ),
          const NavigationDestination(
            label: '비교',
            icon: _CompareIcon(color: _muted),
            selectedIcon: _CompareIcon(color: _green),
          ),
        ],
      ),
    );
  }
}

class _CompareIcon extends StatelessWidget {
  const _CompareIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _CompareIconPainter(color)),
    );
  }
}

class _CompareIconPainter extends CustomPainter {
  const _CompareIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(3, 10, 3, 6),
        const Radius.circular(1),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(9, 5, 3, 11),
        const Radius.circular(1),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(15, 8, 3, 8),
        const Radius.circular(1),
      ),
      paint,
    );
    canvas.drawRect(const Rect.fromLTWH(2, 17, 15, 1.5), paint);
  }

  @override
  bool shouldRepaint(_CompareIconPainter oldDelegate) =>
      oldDelegate.color != color;
}
