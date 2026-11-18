import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/match_record.dart';
import '../../providers/app_providers.dart';
import '../../providers/game_providers.dart';

/// The signed-in player's finished matches, newest first.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  static String modeLabel(GameMode m) => switch (m) {
        GameMode.vsComputer => 'vs Computer',
        GameMode.localMultiplayer => 'Pass & play',
        GameMode.practice => 'Practice',
      };

  static String when(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final history = ref.watch(historyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('HISTORY')),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: AppTheme.background(theme.brightness),
        child: SafeArea(
          child: history.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
            error: (e, _) => Center(child: Text('Could not load history: $e')),
            data: (matches) => matches.isEmpty
                ? Center(
                    child: Text('No games yet. Go roll some dice!', style: theme.textTheme.titleMedium),
                  )
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: matches.length,
                        itemBuilder: (_, i) => _MatchTile(match: matches[i]),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.match});

  final MatchRecord match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final winner = match.winner;
    final won = match.iWon;
    final color = match.myIndex == null ? AppColors.gold : (won ? AppColors.jungleLight : AppColors.sunset);
    final headline = match.myIndex == null
        ? '${winner.avatar} ${winner.name} won'
        : won
            ? '🏆 You won'
            : '${winner.avatar} ${winner.name} beat you';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 48,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(headline, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  Text(
                    '${HistoryScreen.modeLabel(match.mode)} · ${match.players.length} players · ${match.turns} turns · ${HistoryScreen.when(match.endedAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  ),
                ],
              ),
            ),
            Text(
              [for (final p in match.players) p.avatar].join(' '),
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
