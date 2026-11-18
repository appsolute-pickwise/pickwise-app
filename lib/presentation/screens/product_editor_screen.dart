import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/product.dart';
import '../../data/services/pickwise_api.dart';
import '../providers/session_provider.dart';
import '../widgets/product_formatters.dart';

class ProductEditorScreen extends StatefulWidget {
  const ProductEditorScreen({super.key, this.productId, required this.catalog});
  final String? productId;
  final List<Product> catalog;

  @override
  State<ProductEditorScreen> createState() => _ProductEditorScreenState();
}

class _ProductEditorScreenState extends State<ProductEditorScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = {
    for (final key in ['id', 'brand', 'name', 'price', 'date', 'url', 'tags'])
      key: TextEditingController(),
  };
  final _specs = <_SpecDraft>[];
  late final SessionProvider _session;
  late final int _epoch;
  bool _loading = false, _saving = false, _dirty = false;
  String? _error, _image;
  String _site = 'danawa';
  bool _automatic = false;
  int _version = 0;

  @override
  void initState() {
    super.initState();
    _session = context.read<SessionProvider>();
    _epoch = _session.generation;
    _fields['date']!.text = _date(DateTime.now());
    if (widget.productId != null) unawaited(_load());
  }

  String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    if (!_session.isAdmin || _session.generation != _epoch) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _session.api.request(
        'GET',
        '/api/v1/admin/products/${Uri.encodeComponent(widget.productId!)}',
      );
      if (!mounted || _session.generation != _epoch) return;
      final product = Product.fromJson(Map<String, dynamic>.from(data as Map));
      for (final s in _specs) {
        s.dispose();
      }
      _specs.clear();
      _fields['id']!.text = product.id;
      _fields['brand']!.text = product.brand;
      _fields['name']!.text = product.name;
      _fields['price']!.text = '${product.price}';
      _fields['date']!.text = _date(product.priceCheckedAt);
      _fields['url']!.text = product.priceComparisonUrl.toString();
      _fields['tags']!.text = product.tags.join(', ');
      _site = product.priceComparisonSite.name;
      _image = product.imageAsset;
      _automatic = product.priceAutoRefresh;
      _version = product.version;
      _specs.addAll(product.specs.map(_SpecDraft.fromProduct));
      _dirty = false;
    } catch (error) {
      if (mounted && _session.generation == _epoch) {
        _error = error is ApiException
            ? error.message
            : '상품을 불러오지 못했어요. 다시 시도해주세요.';
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _discard() async {
    if (!_dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('작성한 내용을 버릴까요?'),
            content: const Text('저장하지 않은 변경 내용은 사라져요.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('계속 작성'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('버리기'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _save() async {
    if (_saving ||
        !_session.isAdmin ||
        _session.generation != _epoch ||
        !_form.currentState!.validate()) {
      return;
    }
    final id = _fields['id']!.text.trim();
    final payload = <String, dynamic>{
      'id': id,
      'brand': _fields['brand']!.text.trim(),
      'name': _fields['name']!.text.trim(),
      'category': 'earbuds',
      'imageAsset': _image,
      'tags': _tags(),
      'price': int.parse(_fields['price']!.text.trim()),
      'priceCheckedAt': _fields['date']!.text.trim(),
      'priceComparisonSite': _site,
      'priceComparisonUrl': _fields['url']!.text.trim(),
      'priceAutoRefresh': _automatic,
      'version': _version,
      'specs': _specs.map((spec) => spec.toJson()).toList(),
    };
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _session.api.request(
        widget.productId == null ? 'POST' : 'PUT',
        '/api/v1/admin/products${widget.productId == null ? '' : '/${Uri.encodeComponent(id)}'}',
        payload,
      );
      if (mounted && _session.generation == _epoch) {
        setState(() => _dirty = false);
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted && _session.generation == _epoch) {
        setState(
          () => _error = error is ApiException && error.status == 409
              ? '이미 등록된 ID이거나 편집 중 상품이 변경됐어요. 작성 내용은 유지했어요. 목록에서 최신 정보를 확인해주세요.'
              : error is ApiException && [400, 403, 404].contains(error.status)
              ? error.message
              : '저장 결과를 확인하지 못했어요. 다시 저장하기 전에 목록에서 반영 여부를 확인해주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> _tags() => _fields['tags']!.text
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  String? _dateError(String? value, {bool optional = false}) {
    final text = value?.trim() ?? '';
    if (optional && text.isEmpty) return null;
    final parsed = DateTime.tryParse(text);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) ||
        parsed == null ||
        _date(parsed) != text ||
        text.compareTo(_date(DateTime.now())) > 0) {
      return '오늘 이전 날짜를 YYYY-MM-DD로 입력해주세요.';
    }
    return null;
  }

  String? _urlError(String? value, {bool optional = false}) {
    final text = value?.trim() ?? '';
    if (optional && text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    return uri == null ||
            uri.scheme != 'https' ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty ||
            uri.hasFragment ||
            (uri.hasPort && uri.port != 443)
        ? '올바른 HTTPS 출처 링크를 입력해주세요.'
        : null;
  }

  Widget _text(
    String label,
    TextEditingController controller, {
    int maxLength = 120,
    bool readOnly = false,
    TextInputType? keyboard,
    String? Function(String?)? validate,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      enabled: !_saving,
      readOnly: readOnly,
      maxLength: maxLength,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label, counterText: ''),
      onChanged: (_) {
        if (!_dirty) setState(() => _dirty = true);
      },
      validator:
          validate ??
          (value) =>
              value == null || value.trim().isEmpty ? '$label을 입력해주세요.' : null,
    ),
  );

  Future<void> _addSpec() async {
    if (_specs.length >= 40) return;
    final available = _specTemplates.keys
        .where((key) => !_specs.any((s) => s.key == key))
        .toList();
    final key = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('추가할 사양')),
            for (final key in available)
              ListTile(
                title: Text(_specTemplates[key]!.$1),
                onTap: () => Navigator.pop(sheet, key),
              ),
          ],
        ),
      ),
    );
    if (key != null && mounted) {
      setState(() {
        _specs.add(_SpecDraft.empty(key));
        _dirty = true;
      });
    }
  }

  Future<void> _history() async {
    try {
      final rows = await _session.api.request(
        'GET',
        '/api/v1/admin/products/${Uri.encodeComponent(widget.productId!)}/changes',
      ) as List;
      if (!mounted || _session.generation != _epoch) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheet) => SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: .55,
            minChildSize: .3,
            maxChildSize: .9,
            builder: (_, scroll) => ListView(
              controller: scroll,
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  '최근 변경 기록',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                if (rows.isEmpty) const Text('아직 변경 기록이 없어요.'),
                for (final row in rows)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(row['action'] == 'CREATE' ? '상품 등록' : '상품 수정'),
                    subtitle: Text(
                      '${DateTime.parse(row['changedAt'] as String).toLocal()}\n${row['before'] == null ? '' : '${formatPrice(row['before']['price'] as int)}원 → '}${formatPrice(row['after']['price'] as int)}원',
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted && _session.generation == _epoch) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ApiException ? error.message : '변경 기록을 불러오지 못했어요.',
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    for (final s in _specs) {
      s.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allowed =
        context.watch<SessionProvider>().isAdmin &&
        _session.generation == _epoch;
    final photos = <String, String>{
      for (final p in widget.catalog)
        if (p.imageAsset != null) p.imageAsset!: p.name,
    };
    if (_image != null) photos.putIfAbsent(_image!, () => '현재 제품 사진');
    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _saving) return;
        if (await _discard() && mounted) {
          setState(() => _dirty = false);
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.productId == null ? '상품 등록' : '상품 수정'),
          actions: [
            if (allowed && widget.productId != null)
              IconButton(
                tooltip: '변경 기록',
                onPressed: _saving ? null : _history,
                icon: const Icon(Icons.history_rounded),
              ),
          ],
        ),
        body: !allowed
            ? const Center(child: Text('관리자 계정으로 로그인해주세요.'))
            : _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _form,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(_error!),
                        ),
                      if (widget.productId != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _saving
                                ? null
                                : () async {
                                    if (await _discard() && mounted) {
                                      await _load();
                                    }
                                  },
                            child: const Text('서버 정보 다시 불러오기'),
                          ),
                        ),
                      _text(
                        '제품 ID',
                        _fields['id']!,
                        readOnly: widget.productId != null,
                        validate: (value) =>
                            !RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$')
                                .hasMatch(value?.trim() ?? '')
                            ? '영문 소문자·숫자·하이픈을 사용해주세요.'
                            : null,
                      ),
                      _text('브랜드', _fields['brand']!),
                      _text('제품명', _fields['name']!, maxLength: 240),
                      DropdownButtonFormField<String>(
                        initialValue: _image ?? '',
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: '제품 사진'),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('사진 없음'),
                          ),
                          for (final entry in photos.entries)
                            DropdownMenuItem(
                              value: entry.key,
                              child: Text(
                                entry.value,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) => setState(() {
                                _image = value == '' ? null : value;
                                _dirty = true;
                              }),
                      ),
                      const SizedBox(height: 16),
                      _text(
                        '가격 (원)',
                        _fields['price']!,
                        keyboard: TextInputType.number,
                        validate: (value) {
                          final price = int.tryParse(value?.trim() ?? '');
                          return price == null ||
                                  price <= 0 ||
                                  price > 2147483647
                              ? '0보다 큰 정수 가격을 입력해주세요.'
                              : null;
                        },
                      ),
                      _text(
                        '가격 확인일',
                        _fields['date']!,
                        maxLength: 10,
                        validate: _dateError,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _site,
                        decoration: const InputDecoration(labelText: '가격 출처'),
                        items: [
                          for (final site in PriceComparisonSite.values)
                            DropdownMenuItem(
                              value: site.name,
                              child: Text(priceComparisonSiteLabel(site)),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) => setState(() {
                                _site = value!;
                                if (_site != 'danawa') _automatic = false;
                                _dirty = true;
                              }),
                      ),
                      const SizedBox(height: 16),
                      _text(
                        '제품별 가격 출처 링크',
                        _fields['url']!,
                        maxLength: 1000,
                        keyboard: TextInputType.url,
                        validate: _urlError,
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('가격 자동 갱신'),
                        subtitle: const Text(
                          '다나와 제품 링크만 지원해요. 켜면 다음 조회부터 수동 가격이 갱신될 수 있어요.',
                        ),
                        value: _automatic,
                        onChanged: _saving || _site != 'danawa'
                            ? null
                            : (value) => setState(() {
                                _automatic = value;
                                _dirty = true;
                              }),
                      ),
                      const SizedBox(height: 16),
                      _text(
                        '용도 태그 (쉼표로 구분)',
                        _fields['tags']!,
                        maxLength: 800,
                        validate: (_) {
                          final tags = _tags();
                          return tags.length > 8 ||
                                  tags.toSet().length != tags.length ||
                                  tags.any((tag) => tag.length > 100)
                              ? '중복 없이 최대 8개, 태그당 100자까지 입력해주세요.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '제품 사양',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('배터리는 이어버드·케이스 포함 여부와 ANC 조건을 구분해 입력해주세요.'),
                      for (final spec in _specs) _specForm(spec),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _addSpec,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('사양 추가'),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? '저장 중…' : '상품 정보 저장'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _specForm(_SpecDraft spec) => Padding(
    key: ObjectKey(spec),
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                spec.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: '${spec.label} 삭제',
              onPressed: _saving
                  ? null
                  : () => setState(() {
                      _specs.remove(spec);
                      spec.dispose();
                      _dirty = true;
                    }),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        if (spec.type == 'bool')
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: DropdownButtonFormField<String>(
              initialValue: spec.value.text,
              decoration: const InputDecoration(labelText: '지원 여부'),
              items: const [
                DropdownMenuItem(value: 'true', child: Text('지원')),
                DropdownMenuItem(value: 'false', child: Text('미지원')),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                      spec.value.text = value!;
                      _dirty = true;
                    }),
            ),
          )
        else
          _text(
            '${spec.label}${spec.unit == null ? '' : ' (${spec.unit})'}',
            spec.value,
            maxLength: 500,
            keyboard: spec.type == 'number'
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            validate: (value) {
              if (value == null || value.trim().isEmpty) return '사양 값을 입력해주세요.';
              if (spec.type == 'number') {
                final n = num.tryParse(value.trim());
                if (n == null || !n.isFinite || n <= 0 || n > 1000) {
                  return '0보다 크고 1000 이하인 수치를 입력해주세요.';
                }
              }
              return null;
            },
          ),
        _text(
          '사양 출처 링크 (선택)',
          spec.source,
          maxLength: 1000,
          keyboard: TextInputType.url,
          validate: (value) =>
              spec.checked.text.trim().isNotEmpty &&
                  (value?.trim().isEmpty ?? true)
              ? '확인일에 해당하는 출처 링크를 입력해주세요.'
              : _urlError(value, optional: true),
        ),
        _text(
          '사양 확인일 (선택)',
          spec.checked,
          maxLength: 10,
          validate: (value) =>
              spec.source.text.trim().isNotEmpty &&
                  (value?.trim().isEmpty ?? true)
              ? '출처를 확인한 날짜를 입력해주세요.'
              : _dateError(value, optional: true),
        ),
        const Divider(),
      ],
    ),
  );
}

const _specTemplates = <String, (String, String, String?)>{
  'wearType': ('착용 형태', 'text', null),
  'anc': ('노이즈 캔슬링 지원', 'bool', null),
  'batteryHoursAncOn': ('이어버드 재생 시간 (ANC 켬)', 'number', '시간'),
  'batteryHours': ('이어버드 재생 시간 (일반 재생)', 'number', '시간'),
  'maxBatteryHoursAncOn': ('케이스 포함 재생 시간 (ANC 켬)', 'number', '시간'),
  'maxBatteryHours': ('케이스 포함 재생 시간 (일반 재생)', 'number', '시간'),
  'weight': ('이어버드 무게 (한 쪽)', 'number', 'g'),
  'waterResistance': ('방수 등급 (이어버드)', 'text', null),
  'bluetooth': ('블루투스', 'text', null),
  'purchaseType': ('판매 구성', 'text', null),
  'earHook': ('귀걸이형 고정 구조', 'bool', null),
  'fitStyle': ('고정 방식', 'text', null),
};

class _SpecDraft {
  _SpecDraft(
    this.key,
    this.label,
    this.type,
    this.unit,
    String value,
    String source,
    String checked,
  ) : value = TextEditingController(text: value),
      source = TextEditingController(text: source),
      checked = TextEditingController(text: checked);
  factory _SpecDraft.empty(String key) {
    final template = _specTemplates[key]!;
    return _SpecDraft(
      key,
      template.$1,
      template.$2,
      template.$3,
      template.$2 == 'bool' ? 'false' : '',
      '',
      '',
    );
  }
  factory _SpecDraft.fromProduct(ProductSpecification spec) => _SpecDraft(
    spec.key,
    spec.label,
    spec.value is bool
        ? 'bool'
        : spec.value is num
        ? 'number'
        : 'text',
    spec.unit,
    '${spec.value}',
    spec.sourceUrl?.toString() ?? '',
    spec.checkedAt?.toIso8601String().substring(0, 10) ?? '',
  );
  final String key, label, type;
  final String? unit;
  final TextEditingController value, source, checked;
  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'value': type == 'bool'
        ? value.text == 'true'
        : type == 'number'
        ? num.parse(value.text.trim())
        : value.text.trim(),
    'unit': unit,
    'sourceUrl': source.text.trim().isEmpty ? null : source.text.trim(),
    'checkedAt': checked.text.trim().isEmpty ? null : checked.text.trim(),
  };
  void dispose() {
    value.dispose();
    source.dispose();
    checked.dispose();
  }
}
