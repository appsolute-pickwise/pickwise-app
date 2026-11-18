import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/product.dart';
import '../../data/services/pickwise_api.dart';
import '../providers/session_provider.dart';

Future<bool> editProductWatch(
  BuildContext context,
  Product product,
  Map<String, dynamic>? existing,
) async {
  final session = context.read<SessionProvider?>();
  if (session == null || !session.loggedIn) return false;
  final epoch = session.generation;
  final target = await showDialog<String>(
    context: context,
    builder: (_) =>
        _TargetDialog(product: product, existing: existing, epoch: epoch),
  );
  if (target == null || session.generation != epoch) return false;
  await session.api.request(
    'PUT',
    '/api/v1/me/watches/${Uri.encodeComponent(product.id)}',
    {
      'targetPrice': target.isEmpty ? null : int.parse(target),
      'version': existing?['version'] ?? 0,
    },
  );
  return session.generation == epoch;
}

class _TargetDialog extends StatefulWidget {
  const _TargetDialog({
    required this.product,
    required this.existing,
    required this.epoch,
  });
  final Product product;
  final Map<String, dynamic>? existing;
  final int epoch;
  @override
  State<_TargetDialog> createState() => _TargetDialogState();
}

class _TargetDialogState extends State<_TargetDialog> {
  late final controller = TextEditingController(
    text: widget.existing?['targetPrice']?.toString() ?? '',
  );
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.watch<SessionProvider>().generation != widget.epoch) {
      return AlertDialog(
        title: const Text('로그인이 변경됐어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      );
    }
    return AlertDialog(
      title: Text(widget.existing == null ? '관심 제품에 추가' : '목표가 설정'),
      content: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.product.name),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '목표 가격 (원, 선택)'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = int.tryParse(v.trim());
                  return n == null || n <= 0 || n > 2147483647
                      ? '0보다 큰 정수를 입력해주세요.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              const Text(
                '비워두면 관심 제품만 저장해요. 목표가는 저장 후 새로 정상 조회한 가격으로 확인하며, 도달하면 한 번 알려드려요.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(context, controller.text.trim());
            }
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}

class WatchControl extends StatefulWidget {
  const WatchControl({super.key, required this.product});
  final Product product;
  @override
  State<WatchControl> createState() => _WatchControlState();
}

class _WatchControlState extends State<WatchControl> {
  int? _epoch;
  Map<String, dynamic>? _watch;
  bool _busy = false;
  String? _error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = context.watch<SessionProvider?>();
    if (s?.generation != _epoch) {
      _epoch = s?.generation;
      _watch = null;
      _error = null;
      if (s?.loggedIn == true) _load();
    }
  }

  Future<void> _load() async {
    final session = context.read<SessionProvider?>();
    if (session == null || !session.loggedIn) return;
    final epoch = session.generation;
    try {
      final rows =
          await session.api.request('GET', '/api/v1/me/watches') as List;
      if (mounted && epoch == session.generation) {
        setState(() {
          _watch = rows
              .cast<Map>()
              .where((r) => r['productId'] == widget.product.id)
              .map((r) => Map<String, dynamic>.from(r))
              .firstOrNull;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && epoch == session.generation) {
        setState(() => _error = '관심 제품 정보를 불러오지 못했어요.');
      }
    }
  }

  Future<void> _edit() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (await editProductWatch(context, widget.product, _watch)) {
        await _load();
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : '저장 결과를 확인하지 못했어요. 다시 불러와 확인해주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider?>();
    if (session?.loggedIn != true) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : _error != null
              ? _load
              : _edit,
          icon: Icon(
            _watch == null
                ? Icons.favorite_border_rounded
                : Icons.favorite_rounded,
          ),
          label: Text(
            _error != null
                ? '관심 정보 다시 불러오기'
                : _watch == null
                ? '관심 제품 · 목표가 설정'
                : '관심 제품 · 목표가 수정',
          ),
        ),
        if (_error != null) Text(_error!),
      ],
    );
  }
}
