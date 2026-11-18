import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/leaderboard_entry.dart';
import '../../providers/app_providers.dart';

/// Global rankings by rating, all-time and weekly.
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  LeaderboardPeriod _period = LeaderboardPeriod.allTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = ref.watch(leaderboardProvider(_period));
    final me = ref.watch(authStateProvider).value;
    final online = ref.watch(firebaseStatusProvider).value?.available ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('LEADERBOARD')),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: AppTheme.background(theme.brightness),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: SegmentedButton<LeaderboardPeriod>(
                      segments: [
                        for (final p in LeaderboardPeriod.values)
                          ButtonSegment(value: p, label: Text(p.label)),
                      ],
                      selected: {_period},
                      onSelectionChanged: (s) => setState(() => _period = s.first),
                    ),
                  ),
                  if (!online)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: Text(
                        'Offline: showing players on this device only.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                      ),
                    ),
                  Expanded(
                    child: entries.when(
                      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
                      error: (e, _) => Center(child: Text('Could not load leaderboard: $e')),
                      data: (list) => list.isEmpty
                          ? Center(child: Text('No ranked games yet.', style: theme.textTheme.titleMedium))
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: list.length,
                              itemBuilder: (_, i) => _Row(rank: i + 1, entry: list[i], isMe: list[i].uid == me?.uid),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.rank, required this.entry, required this.isMe});

  final int rank;
  final LeaderboardEntry entry;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final medal = switch (rank) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => '#$rank' };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? AppColors.gold.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isMe ? AppColors.gold : Colors.white24, width: isMe ? 2 : 1),
      ),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text(medal, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          Text(entry.avatar, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.displayName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                Text('${entry.wins} wins · ${entry.games} games', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
              ],
            ),
          ),
          Text('${entry.rating}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: AppColors.gold)),
        ],
      ),
    );
  }
}
