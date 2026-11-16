import 'login_screen.dart';
import '../widgets/catalog_receipt.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/services/pickwise_api.dart';
import '../../data/models/product_preferences.dart';
import '../providers/product_provider.dart';
import '../providers/session_provider.dart';
import '../../data/models/product.dart';
import '../widgets/product_formatters.dart';

class ComparisonHistoryScreen extends StatefulWidget {
  const ComparisonHistoryScreen({super.key});
  @override
  State<ComparisonHistoryScreen> createState() =>
      _ComparisonHistoryScreenState();
}

class _ComparisonHistoryScreenState extends State<ComparisonHistoryScreen> {
  SessionProvider get _session => context.read<SessionProvider>();
  PickwiseApi get _api => _session.api;
  int? _loadedGeneration;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = context.watch<SessionProvider>();
    if (_loadedGeneration != session.generation || !session.loggedIn) {
      _records = [];
    }
    if (session.loggedIn && _loadedGeneration != session.generation) {
      _loadedGeneration = session.generation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _run(_load);
      });
    }
  }

  final _title = TextEditingController(text: '나의 비교');
  List<dynamic> _records = [];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() work) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _error = e is ApiException ? e.message : '연결에 실패했어요. 다시 시도해주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    final generation = _session.generation;
    final rows = await _api.request('GET', '/api/v1/me/comparisons');
    if (mounted && generation == _session.generation) {
      setState(() => _records = rows as List);
    }
  }

  Map<String, dynamic> _body(ProductProvider provider) {
    final p = provider.selectionPreferences;
    return {
      'title': _title.text.trim(),
      'productIds': provider.selectedProducts.map((p) => p.id).toList(),
      'preferences': p.toJson(),
      'version': 0,
    };
  }

  Future<void> _showRecord(dynamic row, ProductProvider provider) async {
    final snapshot = row['snapshot'] as Map?;
    final generation = _session.generation;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => Consumer<SessionProvider>(
        builder: (context, session, _) {
          if (session.generation != generation) {
            return const SafeArea(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('계정이 변경되어 기록을 닫아주세요.'),
              ),
            );
          }
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row['title'] as String,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    snapshot == null
                        ? '저장 당시 정보 없음'
                        : '저장 당시 · ${snapshot['savedAt']}',
                  ),
                  const CatalogReceipt(),
                  if (snapshot != null) ...[
                    Text('추천 규칙 ${snapshot['ruleVersion']}'),
                    for (final raw in snapshot['products'] as List) ...[
                      Builder(
                        builder: (_) {
                          final product = Product.fromJson(
                            Map<String, dynamic>.from(raw as Map),
                          );
                          final current = provider.products
                              .where((p) => p.id == product.id)
                              .firstOrNull;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(),
                              Text(product.name),
                              Text(
                                '저장 당시 ${formatPrice(product.price)}원 · 가격 확인일 ${formatCompactDate(product.priceCheckedAt)}',
                              ),
                              Text('출처 ${product.priceComparisonUrl}'),
                              for (final spec in product.specs)
                                Text(
                                  '${spec.label}: ${formatSpecificationValue(spec)}${spec.checkedAt == null ? '' : ' · 확인 ${formatCompactDate(spec.checkedAt!)}'}',
                                ),
                              Text(
                                current == null
                                    ? '현재 정보 없음'
                                    : '현재 정보 ${formatPrice(current.price)}원 · 확인일 ${formatCompactDate(current.priceCheckedAt)}',
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      if (_session.generation != generation) return;
                      provider.restoreComparison(
                        (row['productIds'] as List).cast<String>(),
                        ProductPreferences.fromJson(
                          Map<String, dynamic>.from(row['preferences'] as Map),
                        ),
                      );
                      Navigator.pop(sheet);
                      Navigator.pop(context);
                    },
                    child: const Text('현재 정보로 다시 비교'),
                  ),
                  const Text('다시 비교해도 저장된 원본 기록은 유지돼요.'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final session = context.watch<SessionProvider>();
    if (!session.loggedIn) return const LoginScreen();
    return Scaffold(
      appBar: AppBar(title: const Text('저장한 비교')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        children: [
          if (session.message != null) ...[
            Text(session.message!),
            TextButton(
              onPressed: session.restoring
                  ? null
                  : () => _run(session.initialize),
              child: const Text('로그인 상태 다시 확인'),
            ),
          ],
          if (session.restoring) const LinearProgressIndicator(),
          if (!_api.configured) const Text('서버 주소 설정 후 사용할 수 있어요.'),
          Text(session.email ?? ''),
          TextButton(
            onPressed: _busy
                ? null
                : () => _run(_session.saveDefaultPreferences),
            child: const Text('현재 기준을 기본 취향으로 저장'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => _run(_session.loadDefaultPreferences),
            child: const Text('기본 취향 불러오기'),
          ),
          TextField(
            controller: _title,
            maxLength: 100,
            decoration: const InputDecoration(labelText: '비교 이름'),
          ),
          FilledButton(
            onPressed: _busy || provider.selectedCount == 0
                ? null
                : () => _run(() async {
                    await _api.request(
                      'POST',
                      '/api/v1/me/comparisons',
                      _body(provider),
                    );
                    await _load();
                  }),
            child: const Text('현재 비교와 기준 저장'),
          ),
          TextButton(
            onPressed: _busy ? null : () => _run(_load),
            child: const Text('새로고침'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    await _session.logout();
                    if (mounted) setState(() => _records = []);
                  }),
            child: const Text('로그아웃'),
          ),
          if (_records.isEmpty) const Text('저장한 비교가 없어요.'),
          for (final row in _records)
            ListTile(
              title: Text(row['title'] as String),
              subtitle: Text(
                row['snapshot'] == null
                    ? '저장 당시 정보 없음'
                    : '저장 당시 · ${row['snapshot']['savedAt']}',
              ),
              onTap: _busy
                  ? null
                  : () {
                      _showRecord(row, provider);
                    },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '현재 비교로 덮어쓰기',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: _busy || provider.selectedCount == 0
                        ? null
                        : () => _run(() async {
                            final body = _body(provider)
                              ..['version'] = row['version'];
                            await _api.request(
                              'PUT',
                              '/api/v1/me/comparisons/${row['id']}',
                              body,
                            );
                            await _load();
                          }),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            await _api.request(
                              'DELETE',
                              '/api/v1/me/comparisons/${row['id']}',
                            );
                            await _load();
                          }),
                  ),
                ],
              ),
            ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}
