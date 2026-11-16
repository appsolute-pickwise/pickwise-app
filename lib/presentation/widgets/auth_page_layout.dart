import 'dart:math' as math;

import 'package:flutter/material.dart';

class AuthPageLayout extends StatelessWidget {
  const AuthPageLayout({
    super.key,
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      appBar: canPop
          ? AppBar(leading: const BackButton(), toolbarHeight: 48)
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final top = constraints.maxHeight < 560
                ? 20.0
                : canPop
                ? 24.0
                : 48.0;
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(28, top, 28, 28),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 12 * (1 - value)),
                        child: child,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: PickWiseAuthLogo(),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            letterSpacing: -.6,
                            color: Color(0xFF191F28),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.55,
                            color: Color(0xFF657181),
                          ),
                        ),
                        const SizedBox(height: 30),
                        child,
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class PickWiseAuthLogo extends StatelessWidget {
  const PickWiseAuthLogo({super.key, this.width = 280});
  final double width;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final displayWidth = math.min(width, constraints.maxWidth);
      // 원본 PNG의 실제 로고 영역만 표시한다. 파일과 로고 비율은 유지한다.
      final scale = displayWidth / 817;
      return SizedBox(
        key: const ValueKey('auth-logo-bounds'),
        width: displayWidth,
        height: 235 * scale,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: 0,
            minHeight: 0,
            maxWidth: 1707 * scale,
            maxHeight: 469 * scale,
            child: Transform.translate(
              offset: Offset(-107 * scale, -117 * scale),
              child: Image.asset(
                'assets/images/logo/pickwiselogo.png',
                width: 1707 * scale,
                height: 469 * scale,
                fit: BoxFit.contain,
                semanticLabel: 'PickWise 로고',
              ),
            ),
          ),
        ),
      );
    },
  );
}
