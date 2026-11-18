import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:snakes_ladders/features/game/components/dice_widget.dart';

Widget harness({required int? value, required int? target, required bool rolling}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: DiceWidget(
          value: value,
          targetValue: target,
          isRolling: rolling,
          enabled: !rolling,
          onTap: () {},
          rollDuration: const Duration(milliseconds: 1000),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the settled value', (tester) async {
    for (var v = 1; v <= 6; v++) {
      await tester.pumpWidget(harness(value: v, target: null, rolling: false));
      final state = tester.state<DiceWidgetState>(find.byType(DiceWidget));
      expect(state.shownValue, v);
    }
  });

  testWidgets('tumbles and lands on the target value', (tester) async {
    await tester.pumpWidget(harness(value: null, target: null, rolling: false));
    for (final target in [5, 2, 6, 3, 1, 4]) {
      await tester.pumpWidget(harness(value: null, target: target, rolling: true));
      final state = tester.state<DiceWidgetState>(find.byType(DiceWidget));
      expect(state.isTumbling, isTrue);
      await tester.pump(const Duration(milliseconds: 400));
      expect(state.isTumbling, isTrue);
      // Engine reports the roll finished in one big frame, like a real app
      // after a long frame.
      await tester.pump(const Duration(milliseconds: 720));
      await tester.pumpWidget(harness(value: target, target: target, rolling: false));
      expect(state.isTumbling, isFalse);
      expect(state.shownValue, target, reason: 'target $target');
    }
  });

  testWidgets('a single long frame still lands on the target', (tester) async {
    await tester.pumpWidget(harness(value: null, target: 5, rolling: false));
    await tester.pumpWidget(harness(value: null, target: 5, rolling: true));
    await tester.pump(const Duration(milliseconds: 1120));
    await tester.pumpWidget(harness(value: 5, target: 5, rolling: false));
    final state = tester.state<DiceWidgetState>(find.byType(DiceWidget));
    expect(state.shownValue, 5);
  });
}
