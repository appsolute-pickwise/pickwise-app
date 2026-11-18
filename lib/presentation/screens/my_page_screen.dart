import 'change_password_screen.dart';
import 'delete_account_screen.dart';
import 'watchlist_screen.dart';
import 'admin_products_screen.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/product_preferences.dart';
import '../../data/services/pickwise_api.dart';
import '../providers/app_navigation_controller.dart';
import '../providers/product_provider.dart';
import '../providers/session_provider.dart';
import 'comparison_history_screen.dart';
import 'liking_screen.dart';
import 'login_screen.dart';
import 'product_comparison_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});
  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  bool _busy = false;
  static const _ink = Color(0xFF191F28),
      _muted = Color(0xFF657181),
      _green = Color(0xFF165A4B),
      _line = Color(0xFFE5E8EB);

  Future<void> _run(Future<void> Function() work, {String? success}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await work();
      if (mounted && success != null) _notice(success);
    } catch (error) {
      if (mounted) {
        _notice(error is ApiException ? error.message : '연결을 확인하고 다시 시도해주세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notice(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _login() async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
  }

  void _compare() {
    final navigation = context.read<AppNavigationController?>();
    if (navigation != null) {
      navigation.select(2);
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const ProductComparisonScreen(),
        ),
      );
    }
  }

  Future<void> _preferences() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const LikingScreen(editDefault: true),
      ),
    );
    if (mounted && result == true) _notice('기본 취향을 저장했어요.');
  }

  Future<void> _logout(SessionProvider session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('로그아웃할까요?'),
        content: const Text('저장한 취향과 비교 기록은 계정에 보관돼요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _run(session.logout);
  }

  List<String> _labels(ProductPreferences p) => [
    ...p.priorities,
    if (p.budget != null) p.budget!,
    if (p.wearType != null) p.wearType!,
    if (p.requireAnc) 'ANC 필수',
    if (p.maxWeightGrams != null)
      '${p.maxWeightGrams!.toString().replaceFirst(RegExp(r'\.0$'), '')}g 이하',
  ];

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final products = context.watch<ProductProvider>();
    final preference = session.loggedIn
        ? products.defaultPreferences
        : products.selectionPreferences;
    final labels = preference == null ? <String>[] : _labels(preference);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '마이페이지',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        centerTitle: false,
        titleSpacing: 24,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 29,
                  backgroundColor: Color(0xFFE5F0E9),
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 30,
                    color: _green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.loggedIn ? '내 계정' : '게스트',
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                          letterSpacing: -.6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        session.email ?? '취향을 고르고 비교를 시작해보세요.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!session.loggedIn) ...[
              const SizedBox(height: 22),
              FilledButton(
                style: FilledButton.styleFrom(
                  textStyle: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                onPressed: _busy ? null : _login,
                child: const Text('로그인 · 회원가입'),
              ),
            ],
            const SizedBox(height: 28),
            Material(
              color: const Color(0xFFE5F0E9),
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _compare,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '현재 비교',
                              style: TextStyle(
                                fontSize: 13,
                                color: _green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${products.selectedCount}개 제품',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                                letterSpacing: -.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              products.selectedCount == 0
                                  ? '최대 3개까지 함께 비교할 수 있어요.'
                                  : products.selectedProducts
                                        .map((p) => p.name)
                                        .join(' · '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: _green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 22,
                        color: _green,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '기본 취향',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _preferences,
                  child: const Text('수정'),
                ),
              ],
            ),
            AnimatedSize(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              alignment: Alignment.topLeft,
              child: labels.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 16),
                      child: Text(
                        preference == null
                            ? '저장된 기본 취향을 확인해주세요.'
                            : '아직 저장한 기준이 없어요.',
                        style: const TextStyle(fontSize: 13, color: _muted),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final label in labels)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: _line),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _ink,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            if (session.loggedIn && preference == null)
              TextButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => session.loadDefaultPreferences(
                          applyToSelection: false,
                        ),
                      ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('기본 취향 다시 불러오기'),
              ),
            const Divider(height: 32, color: _line),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                '나의 활동',
                style: TextStyle(
                  fontSize: 13,
                  color: _muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (session.loggedIn) ...[
              _MenuRow(
                icon: Icons.favorite_border_rounded,
                title: '관심 제품',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WatchlistScreen(),
                  ),
                ),
              ),
              _MenuRow(
                icon: Icons.notifications_none_rounded,
                title: '가격 알림함',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WatchlistScreen(alerts: true),
                  ),
                ),
              ),
            ],
            _MenuRow(
              icon: Icons.bookmark_border_rounded,
              title: '저장한 비교',
              subtitle: '이전에 고른 제품과 기준 다시 보기',
              onTap: _busy
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ComparisonHistoryScreen(),
                      ),
                    ),
            ),
            const Divider(height: 32, color: _line),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                '계정 및 앱',
                style: TextStyle(
                  fontSize: 13,
                  color: _muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _MenuRow(
              icon: Icons.info_outline_rounded,
              title: '앱 정보',
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'PickWise',
                children: [const Text('나에게 중요한 기준으로 제품을 비교하고 선택하는 앱입니다.')],
              ),
            ),
            if (session.isAdmin)
              _MenuRow(
                icon: Icons.inventory_2_outlined,
                title: '상품 관리',
                subtitle: '제품·가격·출처 등록 및 수정',
                onTap: _busy
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AdminProductsScreen(),
                        ),
                      ),
              ),
            if (session.loggedIn)
              _MenuRow(
                icon: Icons.lock_outline_rounded,
                title: '비밀번호 변경',
                onTap: _busy
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ChangePasswordScreen(),
                        ),
                      ),
              ),
            if (session.loggedIn)
              _MenuRow(
                icon: Icons.logout_rounded,
                title: '로그아웃',
                onTap: _busy ? null : () => _logout(session),
              ),
            if (session.loggedIn)
              _MenuRow(
                icon: Icons.person_remove_outlined,
                title: '회원 탈퇴',
                onTap: _busy
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DeleteAccountScreen(),
                        ),
                      ),
              ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    minLeadingWidth: 24,
    horizontalTitleGap: 14,
    leading: Icon(icon, size: 22, color: const Color(0xFF657181)),
    title: Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Color(0xFF191F28),
      ),
    ),
    subtitle: subtitle == null
        ? null
        : Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Color(0xFF657181),
            ),
          ),
    trailing: const Icon(
      Icons.chevron_right_rounded,
      size: 20,
      color: Color(0xFF657181),
    ),
    onTap: onTap,
  );
}
