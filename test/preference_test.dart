import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickwise/presentation/screens/liking_screen.dart';

void main() {
  testWidgets('우선순위는 여러 개, 예산은 하나만 선택한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LikingScreen()));

    await tester.tap(find.text('배터리'));
    await tester.tap(find.text('무게'));
    await tester.pump();
    expect(find.text('✓ 배터리'), findsOneWidget);
    expect(find.text('✓ 무게'), findsOneWidget);

    await tester.ensureVisible(find.text('5만원 미만'));
    await tester.tap(find.text('5만원 미만'));
    await tester.pump();
    expect(find.text('✓ 5만원 미만'), findsOneWidget);

    await tester.tap(find.text('5만~15만원'));
    await tester.pump();
    expect(find.text('5만원 미만'), findsOneWidget);
    expect(find.text('✓ 5만~15만원'), findsOneWidget);

    await tester.tap(find.text('✓ 5만~15만원'));
    await tester.pump();
    expect(find.text('5만~15만원'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
