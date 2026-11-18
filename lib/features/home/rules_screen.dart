import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Full rules and controls.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  static const sections = [
    ('🎯', 'Goal', 'Be the first to reach cell 100. Tokens start off the board and enter on cell 1 with your first roll.'),
    ('🎲', 'Rolling', 'Tap the dice (or press Space / Enter on a keyboard) on your turn and move forward that many cells. The board zigzags: left to right, then right to left, all the way up.'),
    ('🪜', 'Ladders', 'Stop at the foot of a ladder and you climb to its top straight away.'),
    ('🐍', 'Snakes', 'Stop on a snake\'s head and it swallows you down to its tail.'),
    ('6️⃣', 'Sixes', 'A six gives you another turn. Three sixes in a row and your turn is forfeited (no move on the third six).'),
    ('🏁', 'Finishing', 'By default you need the exact number to land on 100; a bigger roll means you stay put. Practice mode relaxes this rule.'),
    ('🤖', 'Computer players', 'Easy bots are a bit unlucky and slow, Normal bots roll like you, Hard bots get lucky more often and play fast. This is shown in the setup screen, never hidden.'),
    ('🌍', 'Online', 'Create a private room and share its code, or use Quick match. The server rolls the dice, so nobody can cheat. Idle for 30 seconds and another player may roll for you; leaving a running game counts as a loss.'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('HOW TO PLAY')),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: AppTheme.background(theme.brightness),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                itemCount: sections.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final (emoji, title, body) = sections[i];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 28)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: AppColors.gold)),
                                const SizedBox(height: 4),
                                Text(body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
