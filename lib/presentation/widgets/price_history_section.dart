import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/price_history.dart';
import '../../data/models/product.dart';
import '../../data/services/pickwise_api.dart';
import 'product_formatters.dart';

class PriceHistorySection extends StatefulWidget {
  const PriceHistorySection({super.key, required this.product, this.api});
  final Product product;
  final PickwiseApi? api;

  @override
  State<PriceHistorySection> createState() => _PriceHistorySectionState();
}

class _PriceHistorySectionState extends State<PriceHistorySection> {
  static const _ink = Color(0xFF191F28),
      _muted = Color(0xFF657181),
      _green = Color(0xFF165A4B);
  int _days = 30, _request = 0, _selected = 0, _shown = 10;
  String _kind = 'automatic';
  String? _source, _error;
  bool _loading = false;
  PriceHistory? _history;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant PriceHistorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id ||
        oldWidget.api != widget.api ||
        oldWidget.product.priceComparisonUrl !=
            widget.product.priceComparisonUrl) {
      _history = null;
      _source = null;
      unawaited(_load());
    } else if (oldWidget.product.version != widget.product.version) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final api = widget.api;
    final request = ++_request;
    if (api == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final query = Uri(
      queryParameters: {'days': '$_days', 'kind': _kind, 'source': ?_source},
    ).query;
    try {
      final raw = await api.request(
        'GET',
        '/api/v1/products/${Uri.encodeComponent(widget.product.id)}/price-history?$query',
      );
      final history = PriceHistory.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
      if (!mounted || request != _request) return;
      if (history.productId != widget.product.id ||
          history.days != _days ||
          history.kind != _kind) {
        throw const FormatException('요청과 다른 가격 이력');
      }
      setState(() {
        _history = history;
        _selected = history.points.isEmpty ? 0 : history.points.length - 1;
        _shown = 10;
      });
    } catch (error) {
      if (mounted && request == _request) {
        setState(
          () => _error = error is ApiException && error.status == 404
              ? '이 제품의 가격 이력을 찾을 수 없어요.'
              : '가격 이력을 불러오지 못했어요. 다시 시도해주세요.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  void _filter({int? days, String? kind, String? source}) {
    setState(() {
      _days = days ?? _days;
      _kind = kind ?? _kind;
      _source = source;
      _history = null;
    });
    unawaited(_load());
  }

  String _time(DateTime value) {
    final local = value.toLocal();
    return '${formatCompactDate(local)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openSource(PriceHistorySource source) async {
    try {
      if (await launchUrl(source.url, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {
      /* 사용자에게 아래에서 실패를 안내한다. */
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('가격 출처 링크를 열지 못했어요.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = _history;
    final source = history?.sources
        .where((source) => source.key == history.sourceKey)
        .firstOrNull;
    final points = history?.points ?? const <PriceHistoryPoint>[];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E8EB)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '가격 변동',
            style: TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final days in [7, 30, 90])
                ChoiceChip(
                  label: Text('$days일'),
                  selected: _days == days,
                  onSelected: widget.api == null
                      ? null
                      : (_) => _filter(days: days),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('자동 조회'),
                selected: _kind == 'automatic',
                onSelected: widget.api == null
                    ? null
                    : (_) => _filter(kind: 'automatic'),
              ),
              ChoiceChip(
                label: const Text('수동 입력'),
                selected: _kind == 'manual',
                onSelected: widget.api == null
                    ? null
                    : (_) => _filter(kind: 'manual'),
              ),
            ],
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
          if (widget.api == null)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('서버에 연결하면 가격 이력을 확인할 수 있어요.'),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!),
            if (history != null)
              Text(
                '이전 응답 · ${_time(history.asOf)} 기준',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            TextButton(
              onPressed: _loading ? null : _load,
              child: const Text('가격 이력 다시 불러오기'),
            ),
          ],
          if (history != null) ...[
            if (history.sources.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: DropdownButtonFormField<String>(
                  key: ValueKey(
                    '${history.kind}:${history.days}:${history.sourceKey}',
                  ),
                  initialValue: history.sourceKey,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '가격 출처'),
                  items: [
                    for (var i = 0; i < history.sources.length; i++)
                      DropdownMenuItem(
                        value: history.sources[i].key,
                        child: Text(
                          '${_site(history.sources[i].site)} · ${history.sources[i].current ? '현재 출처' : '이전 출처 $i'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) _filter(source: value);
                  },
                ),
              ),
            const SizedBox(height: 12),
            if (points.isEmpty)
              Text(
                _kind == 'automatic'
                    ? '선택한 기간·출처의 자동 조회 기록이 아직 없어요.'
                    : '선택한 기간·출처의 수동 가격 입력 기록이 아직 없어요.',
              ),
            if (points.isNotEmpty) ...[
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text(
                    '최저 ${formatPrice(history.lowest!)}원',
                    style: const TextStyle(
                      color: _green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '최고 ${formatPrice(history.highest!)}원',
                    style: const TextStyle(color: _muted),
                  ),
                ],
              ),
              if (history.change != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    history.change == 0
                        ? '표시 기록의 시작 대비 변동 없음'
                        : '표시 기록의 시작 대비 ${history.change! > 0 ? '+' : '−'}${formatPrice(history.change!.abs())}원',
                  ),
                ),
              const SizedBox(height: 16),
              Semantics(
                label:
                    '가격 그래프, 기록 ${points.length}개, 최저 ${history.lowest}원, 최고 ${history.highest}원',
                child: LayoutBuilder(
                  builder: (context, constraints) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final fraction =
                          ((details.localPosition.dx - 8) /
                                  (constraints.maxWidth - 16))
                              .clamp(0.0, 1.0);
                      final first =
                              points.first.observedAt.microsecondsSinceEpoch,
                          last = points.last.observedAt.microsecondsSinceEpoch;
                      final target = first + (last - first) * fraction;
                      var nearest = 0;
                      for (var i = 1; i < points.length; i++) {
                        if ((points[i].observedAt.microsecondsSinceEpoch -
                                    target)
                                .abs() <
                            (points[nearest].observedAt.microsecondsSinceEpoch -
                                    target)
                                .abs()) {
                          nearest = i;
                        }
                      }
                      setState(() => _selected = nearest);
                    },
                    child: CustomPaint(
                      key: const ValueKey('price-history-chart'),
                      size: Size(constraints.maxWidth, 156),
                      painter: _PricePainter(points, _selected),
                    ),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _time(points.first.observedAt),
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ),
                  if (points.length > 1)
                    Expanded(
                      child: Text(
                        _time(points.last.observedAt),
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: _muted, fontSize: 11),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${_time(points[_selected].observedAt)} · ${formatPrice(points[_selected].price)}원',
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (points.length == 1)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('첫 기록이에요. 다음 조회부터 변화를 확인할 수 있어요.'),
                ),
              if (_kind == 'manual')
                Text(
                  '가격 확인일 ${formatCompactDate(points[_selected].checkedAt)} · 그래프는 입력 시점 기준',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('최근 기록 보기'),
                children: [
                  for (final point in points.reversed.take(_shown))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${formatPrice(point.price)}원'),
                      subtitle: Text(
                        '${_time(point.observedAt)}${_kind == 'manual' ? '\n확인일 ${formatCompactDate(point.checkedAt)}' : ''}',
                      ),
                    ),
                  if (points.length > _shown)
                    TextButton(
                      onPressed: () => setState(() => _shown += 10),
                      child: const Text('기록 10개 더 보기'),
                    ),
                ],
              ),
            ],
            if (source != null)
              TextButton(
                onPressed: () => _openSource(source),
                child: Text('${_site(source.site)} 출처 보기 ↗'),
              ),
            if (history.truncated)
              const Text(
                '기록이 많아 최근 3,000건을 표시해요. 최저·최고도 표시 기록 기준이에요.',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            const SizedBox(height: 4),
            Text(
              _kind == 'automatic'
                  ? '조회 시점의 가격만 기록해요. 기록 사이의 가격과 배송비·쿠폰 조건은 판매처에서 확인해주세요.'
                  : '관리자가 입력한 가격이에요. 자동 조회 가격과 분리해서 보여줘요.',
              style: const TextStyle(color: _muted, fontSize: 12, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  String _site(String site) => switch (site) {
    'danawa' => '다나와',
    'enuri' => '에누리',
    'naver' => '네이버 쇼핑',
    _ => '가격 출처',
  };
}

class _PricePainter extends CustomPainter {
  _PricePainter(this.points, this.selected);
  final List<PriceHistoryPoint> points;
  final int selected;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final grid = Paint()
      ..color = const Color(0xFFE5E8EB)
      ..strokeWidth = 1;
    for (final y in [8.0, size.height / 2, size.height - 8]) {
      canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), grid);
    }
    final low = points
        .map((p) => p.price)
        .reduce((a, b) => a < b ? a : b)
        .toDouble();
    final high = points
        .map((p) => p.price)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    final padding = high == low
        ? (high * .05).clamp(1, double.infinity)
        : (high - low) * .12;
    final min = low - padding, max = high + padding;
    final first = points.first.observedAt.microsecondsSinceEpoch,
        last = points.last.observedAt.microsecondsSinceEpoch;
    Offset position(PriceHistoryPoint point) => Offset(
      first == last
          ? size.width / 2
          : 8 +
                (size.width - 16) *
                    (point.observedAt.microsecondsSinceEpoch - first) /
                    (last - first),
      size.height - 8 - (size.height - 16) * (point.price - min) / (max - min),
    );
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = position(points[i]);
      if (i == 0 ||
          points[i].observedAt.difference(points[i - 1].observedAt) >
              const Duration(hours: 6)) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF165A4B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    final dot = Paint()..color = const Color(0xFF165A4B);
    for (var i = 0; i < points.length; i++) {
      if (points.length <= 60 ||
          i == 0 ||
          i == points.length - 1 ||
          i == selected ||
          (i > 0 &&
              points[i].observedAt.difference(points[i - 1].observedAt) >
                  const Duration(hours: 6)) ||
          (i + 1 < points.length &&
              points[i + 1].observedAt.difference(points[i].observedAt) >
                  const Duration(hours: 6))) {
        canvas.drawCircle(position(points[i]), i == selected ? 4.5 : 2.5, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PricePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.selected != selected;
}
