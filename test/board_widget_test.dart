import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:snakes_ladders/features/game/board/board_painter.dart';
import 'package:snakes_ladders/features/game/board/board_widget.dart';
import 'package:snakes_ladders/features/game/components/player_token.dart';
import 'package:snakes_ladders/features/game/engine/game_engine.dart';
import 'package:snakes_ladders/features/game/models/board_config.dart';
import 'package:snakes_ladders/features/game/models/game_state.dart';
import 'package:snakes_ladders/features/game/models/player.dart';

const players = [
  Player(id: 'a', name: 'Ann', colorIndex: 0, position: 87),
  Player(id: 'b', name: 'Ben', colorIndex: 1, position: 5),
];

Widget board(GameState state) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: BoardWidget(
            size: 400,
            board: BoardConfig.classic,
            state: state,
            timings: const EngineTimings(),
          ),
        ),
      ),
    );

/// Token centre in board coordinates (inside the wooden border, minus the
/// small drop offset tokens are drawn with).
Offset tokenCenter(WidgetTester tester, String id) {
  const cs = 40.0;
  final origin = tester.getTopLeft(find.byType(BoardWidget)) + const Offset(cs * 0.09, cs * 0.09);
  return tester.getCenter(find.byKey(ValueKey('token-$id'))) - origin - const Offset(cs * 0.05, cs * 0.08);
}

void main() {
  testWidgets('token slides along the snake spine from head to tail', (tester) async {
    final layout = BoardLayout(size: 400, board: BoardConfig.classic);
    final snake = layout.snakeAt(87)!;
    const timings = EngineTimings();

    await tester.pumpWidget(board(GameState(players: players)));
    final start = tokenCenter(tester, 'a');
    expect((start - snake.headCenter).distance, lessThan(2));

    await tester.pumpWidget(board(GameState(
      players: players,
      phase: GamePhase.slidingSnake,
      transitionFrom: 87,
      transitionTo: 24,
    )));
    await tester.pump();
    final total = timings.snakeDuration(87, 24);
    await tester.pump(total * 0.5);
    final mid = tokenCenter(tester, 'a');
    // Mid slide: well away from both ends and close to the spine.
    expect((mid - snake.headCenter).distance, greaterThan(40));
    expect((mid - snake.tailCenter).distance, greaterThan(40));
    var nearest = double.infinity;
    for (var t = 0.0; t <= 1; t += 0.01) {
      final d = (snake.swayedPointAt(t, 0, 40, intensity: 2.6) - mid).distance;
      if (d < nearest) nearest = d;
    }
    expect(nearest, lessThan(14));

    await tester.pump(total);
    final end = tokenCenter(tester, 'a');
    expect((end - snake.tailCenter).distance, lessThan(2));
    expect(find.byType(PlayerToken), findsNWidgets(2));
  });

  testWidgets('token climbs the ladder to the top', (tester) async {
    final layout = BoardLayout(size: 400, board: BoardConfig.classic);
    final ladder = layout.ladderAt(28)!;
    const climbing = [
      Player(id: 'a', name: 'Ann', colorIndex: 0, position: 28),
      Player(id: 'b', name: 'Ben', colorIndex: 1, position: 5),
    ];
    await tester.pumpWidget(board(GameState(players: climbing)));
    await tester.pumpWidget(board(GameState(
      players: climbing,
      phase: GamePhase.climbingLadder,
      transitionFrom: 28,
      transitionTo: 84,
    )));
    await tester.pump();
    final total = const EngineTimings().ladderDuration(28, 84);
    await tester.pump(total * 0.5);
    final mid = tokenCenter(tester, 'a');
    final distToLine = _distanceToSegment(mid, ladder.bottomCenter, ladder.topCenter);
    expect(distToLine, lessThan(8));
    expect((mid - ladder.bottomCenter).distance, greaterThan(40));

    await tester.pump(total);
    final end = tokenCenter(tester, 'a');
    expect((end - ladder.topCenter).distance, lessThan(2));
  });
}

double _distanceToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final t = ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / (ab.dx * ab.dx + ab.dy * ab.dy);
  final proj = a + ab * t.clamp(0.0, 1.0);
  return (p - proj).distance;
}
