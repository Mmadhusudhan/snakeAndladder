import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:snakes_ladders/features/game/models/game_state.dart';
import 'package:snakes_ladders/features/game/models/player.dart';
import 'package:snakes_ladders/features/game/screens/game_result_screen.dart';

void main() {
  testWidgets('shows winner, ranking and returns the chosen action', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = GameState(
      players: const [
        Player(id: 'a', name: 'Ann', colorIndex: 0, position: 60),
        Player(id: 'b', name: 'Mango', colorIndex: 1, position: 100, type: PlayerType.computer, botId: 'mango'),
      ],
      stats: const [PlayerStats(rolls: 12, snakes: 2), PlayerStats(rolls: 11, ladders: 3, sixes: 1)],
      phase: GamePhase.completed,
      winnerIndex: 1,
      turnNumber: 23,
      completedAt: DateTime.now(),
    );

    ResultAction? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async => result = await GameResultScreen.show(context, state),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Mango wins!'), findsOneWidget);
    expect(find.textContaining('Monkey business'), findsOneWidget);
    expect(find.textContaining('23 turns'), findsOneWidget);
    expect(find.text('🥇'), findsOneWidget);
    expect(find.text('🥈'), findsOneWidget);
    // Winner listed first.
    final gold = tester.getTopLeft(find.text('🥇'));
    final silver = tester.getTopLeft(find.text('🥈'));
    expect(gold.dy, lessThan(silver.dy));
    expect(find.textContaining('🪜 3'), findsOneWidget);

    await tester.tap(find.text('Players'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(result, ResultAction.changePlayers);
  });
}
