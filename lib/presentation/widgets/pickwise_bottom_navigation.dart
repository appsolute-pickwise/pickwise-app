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
      navigation?.select(tab.index);
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    return Container(
      height: 76,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E8EB))),
      ),
      child: Row(
        children: [
          _NavigationItem(
            label: '홈',
            selected: activeTab == PickWiseTab.home,
            onTap: navigation == null ? null : () => select(PickWiseTab.home),
            icon: SvgPicture.asset('assets/images/figma/home.svg'),
          ),
          _NavigationItem(
            label: '탐색',
            selected: activeTab == PickWiseTab.explore,
            onTap: navigation == null
                ? null
                : () => select(PickWiseTab.explore),
            icon: SvgPicture.asset('assets/images/figma/search.svg'),
          ),
          _NavigationItem(
            label: '비교',
            selected: activeTab == PickWiseTab.compare,
            onTap: navigation == null
                ? null
                : () => select(PickWiseTab.compare),
            icon: _CompareIcon(
              color: activeTab == PickWiseTab.compare ? _green : _muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.label,
    required this.selected,
    required this.icon,
    this.onTap,
  });

  final String label;
  final bool selected;
  final Widget icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? PickWiseBottomNavigation._green
        : PickWiseBottomNavigation._muted;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 20, height: 20, child: Center(child: icon)),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  height: 1.4,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
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
