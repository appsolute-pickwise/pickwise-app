import 'package:flutter/material.dart';

import '../../data/models/product_preferences.dart';

class ImportanceControls extends StatelessWidget {
  const ImportanceControls({
    super.key,
    required this.preferences,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
  });

  final ProductPreferences preferences;
  final ValueChanged<ProductPreferences> onChanged;
  final VoidCallback? onChangeStart;
  final VoidCallback? onChangeEnd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (preferences.priorities.isNotEmpty) ...[
        const Text(
          '기준별 중요도',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          '1은 낮게, 5는 높게 반영해요. 필수 조건은 중요도와 관계없이 지켜요.',
          style: TextStyle(fontSize: 12, color: Color(0xFF657181)),
        ),
      ],
      for (final priority in preferences.priorities.toSet()) ...[
        const SizedBox(height: 12),
        Text('$priority 중요도 ${preferences.weightFor(priority)} / 5'),
        Slider(
          key: ValueKey('weight-$priority'),
          value: preferences.weightFor(priority).toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          activeColor: const Color(0xFF477966),
          label: '${preferences.weightFor(priority)}',
          semanticFormatterCallback: (value) =>
              '$priority 중요도 ${value.round()} / 5',
          onChangeStart: (_) => onChangeStart?.call(),
          onChangeEnd: (_) => onChangeEnd?.call(),
          onChanged: (value) => onChanged(
            preferences.withWeights({
              ...preferences.weights,
              priority: value.round(),
            }),
          ),
        ),
      ],
    ],
  );
}
