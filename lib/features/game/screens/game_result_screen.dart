import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../models/game_state.dart';

/// What the player chose on the result screen.
enum ResultAction { playAgain, changePlayers, home }

/// Full-screen match summary: winner celebration, ranking and stats.
class GameResultScreen extends StatefulWidget {
  const GameResultScreen({super.key, required this.state});

  final GameState state;

  static Future<ResultAction?> show(BuildContext context, GameState state) {
    return Navigator.of(context).push<ResultAction>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => GameResultScreen(state: state),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween(begin: 0.92, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  State<GameResultScreen> createState() => _GameResultScreenState();
}

class _GameResultScreenState extends State<GameResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..forward();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  String _duration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final winner = state.winner;
    final theme = Theme.of(context);
    final ranking = state.ranking;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _confetti,
                builder: (_, _) => CustomPaint(painter: ConfettiPainter(_confetti.value)),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Card(
                  margin: const EdgeInsets.all(20),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🏆', style: TextStyle(fontSize: 64)),
                          const SizedBox(height: 6),
                          Text(
                            winner == null ? 'Game over' : '${winner.name} wins!',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppColors.gold,
                            ),
                          ),
                          if (winner?.personality?.remarkFor(GameEventType.won, state.turnNumber)
                              case final line?)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('“$line”', style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            '${state.turnNumber} turns · ${_duration(state.elapsed)}',
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                          ),
                          const SizedBox(height: 18),
                          for (final (rank, i) in ranking.indexed)
                            _RankRow(
                              rank: rank + 1,
                              state: state,
                              index: i,
                            ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.pop(context, ResultAction.playAgain),
                              icon: const Icon(Icons.replay_rounded),
                              label: const Text('PLAY AGAIN'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context, ResultAction.changePlayers),
                                  child: const Text('Players'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context, ResultAction.home),
                                  child: const Text('Home'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.state, required this.index});

  final int rank;
  final GameState state;
  final int index;

  @override
  Widget build(BuildContext context) {
    final p = state.players[index];
    final st = state.stats[index];
    final color = AppColors.players[p.colorIndex % AppColors.players.length];
    final theme = Theme.of(context);
    final isWinner = state.winnerIndex == index;
    final medal = switch (rank) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => '$rank.' };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isWinner ? 0.28 : 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isWinner ? AppColors.gold : color.withValues(alpha: 0.5), width: isWinner ? 2 : 1),
      ),
      child: Row(
        children: [
          Text(medal, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color, border: Border.all(color: Colors.white, width: 2)),
            alignment: Alignment.center,
            child: Text(p.avatar, style: const TextStyle(fontSize: 18, height: 1)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                Text(
                  '🎲 ${st.rolls}   6️⃣ ${st.sixes}   🪜 ${st.ladders}   🐍 ${st.snakes}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                ),
              ],
            ),
          ),
          Text(
            '${p.position}',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }
}

/// Falling confetti, deterministic so it is cheap and testable.
class ConfettiPainter extends CustomPainter {
  ConfettiPainter(this.t);

  final double t;
  static final _rng = math.Random(7);
  static final List<_Flake> _flakes = List.generate(90, (_) => _Flake.random(_rng));

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) return;
    final fade = t > 0.75 ? 1 - (t - 0.75) / 0.25 : 1.0;
    for (final f in _flakes) {
      final y = ((f.y0 + t * f.speed) % 1.2) - 0.1;
      final x = f.x + math.sin(t * 6 * math.pi * f.wobble + f.phase) * 0.03;
      final paint = Paint()..color = f.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(x * size.width, y * size.height);
      canvas.rotate(t * 10 * f.spin + f.phase);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: f.w, height: f.h), const Radius.circular(1.5)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter old) => old.t != t;
}

class _Flake {
  _Flake(this.x, this.y0, this.speed, this.w, this.h, this.color, this.spin, this.wobble, this.phase);

  final double x, y0, speed, w, h, spin, wobble, phase;
  final Color color;

  static const _palette = [AppColors.gold, AppColors.sunset, AppColors.jungleLight, Color(0xFF2F80ED), Color(0xFFE53950), Colors.white];

  factory _Flake.random(math.Random r) => _Flake(
        r.nextDouble(),
        r.nextDouble(),
        0.5 + r.nextDouble() * 0.9,
        6 + r.nextDouble() * 6,
        8 + r.nextDouble() * 8,
        _palette[r.nextInt(_palette.length)],
        (r.nextDouble() - 0.5) * 2,
        0.5 + r.nextDouble(),
        r.nextDouble() * math.pi * 2,
      );
}
