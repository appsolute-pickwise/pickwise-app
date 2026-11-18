import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/services/pickwise_api.dart';
import '../providers/session_provider.dart';
import '../providers/product_provider.dart';
import '../widgets/product_formatters.dart';
import '../widgets/watch_control.dart';
import 'product_detail_screen.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key, this.alerts = false});
  final bool alerts;
  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen>
    with WidgetsBindingObserver {
  late SessionProvider _session;
  late int _epoch;
  List<Map<String, dynamic>> _rows = [];
  bool _busy = false;
  bool _pushBusy = false;
  String? _error;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _session = context.read<SessionProvider>();
    _epoch = _session.generation;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
    _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_busy) unawaited(_load());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _timer?.cancel();
    if (state == AppLifecycleState.resumed) {
      unawaited(_load());
      _start();
    }
  }

  Future<void> _load() async {
    if (!_session.loggedIn || _epoch != _session.generation) return;
    setState(() => _busy = true);
    try {
      final rows = await _session.api.request(
        'GET',
        '/api/v1/me/${widget.alerts ? 'alerts' : 'watches'}',
      ) as List;
      if (mounted && _epoch == _session.generation) {
        setState(() {
          _rows = rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && _epoch == _session.generation) {
        setState(
          () => _error = e is ApiException ? e.message : '연결을 확인하고 다시 시도해주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(Map<String, dynamic> row) async {
    final p = context
        .read<ProductProvider>()
        .products
        .where((p) => p.id == row['productId'])
        .firstOrNull;
    try {
      if (widget.alerts) {
        await _session.api.request(
          'PUT',
          '/api/v1/me/alerts/${row['id']}/read',
        );
      }
      if (!mounted || _epoch != _session.generation) return;
      if (p == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('현재 제품 목록을 다시 불러와주세요.')));
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProductDetailScreen(product: p),
        ),
      );
      if (mounted) await _load();
    } catch (e) {
      if (mounted && _epoch == _session.generation) {
        setState(
          () => _error = e is ApiException ? e.message : '정보를 확인하지 못했어요.',
        );
      }
    }
  }

  Future<void> _remove(Map<String, dynamic> row) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('관심 제품에서 삭제할까요?'),
        content: const Text('이 제품의 목표가 알림도 중단돼요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted || _epoch != _session.generation) return;
    try {
      await _session.api.request(
        'DELETE',
        '/api/v1/me/watches/${row['productId']}',
      );
      await _load();
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _error = e is ApiException ? e.message : '삭제 결과를 확인하고 다시 시도해주세요.',
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(widget.alerts ? '가격 알림함' : '관심 제품')),
      body: !session.loggedIn || session.generation != _epoch
          ? const Center(child: Text('로그인 후 확인할 수 있어요.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  if (widget.alerts) ...[
                    OutlinedButton.icon(
                      onPressed: _busy || _pushBusy
                          ? null
                          : () async {
                              setState(() => _pushBusy = true);
                              try {
                                await _session.push.enable(_session.userId!);
                                if (mounted && _epoch == _session.generation) {
                                  setState(() => _error = _session.push.status);
                                }
                              } catch (e) {
                                if (mounted && _epoch == _session.generation) {
                                  setState(
                                    () => _error = e is ApiException
                                        ? e.message
                                        : 'Firebase 앱 등록·APNs 설정을 확인해주세요.',
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _pushBusy = false);
                              }
                            },
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('이 기기에서 푸시 받기'),
                    ),
                    TextButton(
                      onPressed: _pushBusy
                          ? null
                          : () async {
                              setState(() => _pushBusy = true);
                              try {
                                await _session.push.disable();
                                if (mounted) {
                                  setState(() => _error = '기기 푸시를 해제했어요.');
                                }
                              } catch (_) {
                                if (mounted) {
                                  setState(
                                    () => _error =
                                        '서버의 해제 결과를 확인하지 못했어요. 다시 시도해주세요.',
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _pushBusy = false);
                              }
                            },
                      child: const Text('이 기기의 푸시 해제'),
                    ),
                  ],
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null) ...[
                    Text(_error!),
                    TextButton(onPressed: _load, child: const Text('다시 불러오기')),
                  ],
                  if (!_busy && _rows.isEmpty)
                    Text(
                      widget.alerts
                          ? '아직 도착한 가격 알림이 없어요.'
                          : '제품 상세에서 관심 제품과 목표가를 저장해보세요.',
                    ),
                  for (final row in _rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(row['name'] as String),
                            onTap: () => _open(row),
                            leading: Icon(
                              widget.alerts
                                  ? (row['read'] == true
                                        ? Icons.notifications_none_rounded
                                        : Icons.notifications_active_outlined)
                                  : Icons.favorite_border_rounded,
                            ),
                            subtitle: Text(
                              widget.alerts
                                  ? '${formatPrice(row['price'] as int)}원 도달 · 목표 ${formatPrice(row['targetPrice'] as int)}원\n${DateTime.parse(row['observedAt'] as String).toLocal()}'
                                  : '등록 가격 ${formatPrice(row['price'] as int)}원\n${row['targetPrice'] == null ? '목표가 없음' : '목표 ${formatPrice(row['targetPrice'] as int)}원 · ${row['armed'] == true ? '알림 대기' : '알림 완료'}'}${row['sourceChanged'] == true ? '\n출처가 바뀌었어요. 목표가를 다시 확인해주세요.' : ''}',
                            ),
                          ),
                          if (!widget.alerts)
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    final p = context
                                        .read<ProductProvider>()
                                        .products
                                        .where((p) => p.id == row['productId'])
                                        .firstOrNull;
                                    if (p == null) return;
                                    try {
                                      if (await editProductWatch(
                                        context,
                                        p,
                                        row,
                                      )) {
                                        await _load();
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        setState(
                                          () => _error = e is ApiException
                                              ? e.message
                                              : '저장 결과를 확인해주세요.',
                                        );
                                      }
                                    }
                                  },
                                  child: const Text('목표가 수정 · 다시 알림'),
                                ),
                                TextButton(
                                  onPressed: () => _remove(row),
                                  child: const Text('관심 해제'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  if (widget.alerts)
                    const Text(
                      '최근 알림 100개 · 조회 당시 가격이며 최종 결제 조건은 판매처에서 확인해주세요.',
                    ),
                ],
              ),
            ),
    );
  }
}
