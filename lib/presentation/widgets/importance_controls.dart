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
      if (preferences.priorities.contains('배터리'))
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: preferences.batteryCondition,
          decoration: const InputDecoration(labelText: '이어버드 배터리 측정 조건'),
          items: const [
            DropdownMenuItem(value: 'ancOn', child: Text('ANC 켬')),
            DropdownMenuItem(value: 'normal', child: Text('일반 재생')),
          ],
          onChanged: (value) {
            if (value != null) {
              onChanged(preferences.withBatteryCondition(value));
            }
          },
        ),
      const Text('ANC·방수는 정보 확인 항목이며 성능 점수에 반영하지 않아요.'),
      for (final priority in preferences.priorities.toSet()) ...[
        const SizedBox(height: 12),
        Text('$priority 중요도 ${preferences.weightFor(priority)} / 5'),
        if (priority == '배터리' || priority == '무게')
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
