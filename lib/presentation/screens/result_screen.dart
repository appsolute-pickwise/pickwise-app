import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/product_preferences.dart';
import '../../data/models/product.dart';
import '../providers/app_navigation_controller.dart';
import '../providers/product_provider.dart';
import '../widgets/pickwise_bottom_navigation.dart';
import '../widgets/importance_controls.dart';
import '../widgets/product_list_tile.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    this.preferences = const ProductPreferences(),
  });

  final ProductPreferences preferences;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late ProductPreferences _preferences;
  int _rankedVisible = 3, _referenceVisible = 3;
  String? _identity;
  ProductPreferences? _beforeRelaxation;
  String? _changeExplanation;
  Map<String, int> _rankChanges = {};
  ProductPreferences? _interactionStart;
  List<Product>? _initialRanking;

  @override
  void initState() {
    super.initState();
    _preferences = widget.preferences;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.watch<ProductProvider>();
    if (_identity != null && _identity != provider.identity) {
      _preferences = provider.selectionPreferences;
      _beforeRelaxation = null;
      _rankChanges = {};
      _changeExplanation = null;
      _rankedVisible = 3;
      _referenceVisible = 3;
    }
    _identity = provider.identity;
  }

  void _updateImportance(ProductPreferences next, ProductProvider provider) {
    final baseline = _interactionStart ?? _preferences;
    final before = _initialRanking ?? baseline.recommend(provider.products);
    final after = next.recommend(provider.products);
    final changed = next.priorities.where(
      (key) => next.weightFor(key) != _preferences.weightFor(key),
    );
    if (changed.isEmpty) {
      setState(() {
        _preferences = next;
        _rankedVisible = 3;
        _referenceVisible = 3;
      });
      provider.updateSelectionPreferences(next);
      return;
    }
    final key = changed.first;
    final reason = baseline.weightFor(key) == next.weightFor(key)
        ? '$key 중요도를 시작 값 ${next.weightFor(key)}단계로 되돌렸어요.'
        : '$key 중요도를 ${baseline.weightFor(key)}단계에서 ${next.weightFor(key)}단계로 변경했어요.';
    final changes = <String, int>{};
    for (var index = 0; index < after.length; index++) {
      final previous = before.indexWhere((p) => p.id == after[index].id);
      if (previous >= 0 && previous != index) {
        changes[after[index].id] = previous - index;
      }
    }
    setState(() {
      _rankedVisible = 3;
      _referenceVisible = 3;
      _preferences = next;
      _rankChanges = changes;
      _changeExplanation = after.isEmpty
          ? reason
          : before.isNotEmpty && before.first.id != after.first.id
          ? '$reason 첫 후보가 ${before.first.name}에서 ${after.first.name}(으)로 바뀌었어요.'
          : '$reason ${changes.isEmpty ? '현재 순위는 유지돼요.' : '첫 후보는 유지되고 다른 후보 순서가 바뀌었어요.'}';
    });
    provider.updateSelectionPreferences(next);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final candidates = _preferences.recommend(provider.products);
    final references = _preferences.referenceCandidates(provider.products);
    return Scaffold(
      appBar: AppBar(title: const Text('맞춤 추천')),
      bottomNavigationBar: const PickWiseBottomNavigation(
        selectedTab: PickWiseTab.home,
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.hasLoadError
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(provider.loadErrorMessage),
                  ElevatedButton(
                    onPressed: provider.loadProducts,
                    child: const Text('다시 불러오기'),
                  ),
                ],
              ),
            )
          : candidates.isEmpty && references.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('조건에 맞는 제품이 없습니다.'),
                      const SizedBox(height: 12),
                      for (final reason in _preferences.emptyResultReasons(
                        provider.products,
                      ))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(reason),
                        ),
                      const Text(
                        '한 제품이 여러 조건에서 제외될 수 있어요.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF657181),
                        ),
                      ),
                      for (final proposal in _preferences.relaxations(
                        provider.products,
                      ))
                        TextButton(
                          onPressed: () => setState(() {
                            _beforeRelaxation = _preferences;
                            _preferences = proposal.preferences;
                            _rankedVisible = 3;
                            _referenceVisible = 3;
                            provider.updateSelectionPreferences(_preferences);
                          }),
                          child: Text(proposal.label),
                        ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('기준 다시 고르기'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '선택한 조건에 가까운 제품',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(_preferences.orderingExplanation),
                  if (_beforeRelaxation != null)
                    TextButton(
                      onPressed: () => setState(() {
                        _preferences = _beforeRelaxation!;
                        _beforeRelaxation = null;
                        _rankedVisible = 3;
                        _referenceVisible = 3;
                        provider.updateSelectionPreferences(_preferences);
                      }),
                      child: const Text('조건 완화 되돌리기'),
                    ),
                  const SizedBox(height: 16),
                  ImportanceControls(
                    preferences: _preferences,
                    onChangeStart: () {
                      _interactionStart = _preferences;
                      _initialRanking = _preferences.recommend(
                        provider.products,
                      );
                    },
                    onChangeEnd: () {
                      _interactionStart = null;
                      _initialRanking = null;
                    },
                    onChanged: (value) => _updateImportance(value, provider),
                  ),
                  if (_changeExplanation != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _changeExplanation!,
                        key: const ValueKey('ranking-change'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  for (
                    var index = 0;
                    index < candidates.take(_rankedVisible).length;
                    index++
                  ) ...[
                    Text(
                      index == 0 ? '먼저 살펴볼 제품' : '함께 비교해 볼 제품',
                      style: const TextStyle(
                        color: Color(0xFF477966),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_rankChanges[candidates[index].id]
                        case final int change)
                      Text(
                        '${change > 0 ? '↑' : '↓'} ${change.abs()}순위',
                        style: const TextStyle(color: Color(0xFF477966)),
                      ),
                    ProductListTile(product: candidates[index]),
                    for (final reason in _preferences.reasons(
                      candidates[index],
                    ))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('• $reason'),
                      ),
                    const SizedBox(height: 16),
                  ],
                  if (candidates.length > _rankedVisible)
                    TextButton(
                      onPressed: () => setState(() => _rankedVisible += 3),
                      child: const Text('순위 후보 더 보기'),
                    ),
                  if (references.isNotEmpty)
                    const Text(
                      '참고 후보',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  for (final product in references.take(_referenceVisible)) ...[
                    ProductListTile(product: product),
                    for (final reason in _preferences.referenceReasons(product))
                      Text(reason),
                  ],
                  if (references.length > _referenceVisible)
                    TextButton(
                      onPressed: () => setState(() => _referenceVisible += 3),
                      child: const Text('참고 후보 더 보기'),
                    ),
                  FilledButton(
                    onPressed: provider.selectedCount == 0
                        ? null
                        : () {
                            provider.updateSelectionPreferences(_preferences);
                            context.read<AppNavigationController>().select(2);
                            Navigator.of(context)
                                .popUntil((route) => route.isFirst);
                          },
                    child: Text('선택한 ${provider.selectedCount}개 제품 비교하기'),
                  ),
                ],
              ),
            ),
    );
  }
}
