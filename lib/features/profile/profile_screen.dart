import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_profile.dart';
import '../../providers/app_providers.dart';
import '../authentication/login_screen.dart';
import 'history_screen.dart';

/// Name, avatar, lifetime stats, history link and sign-out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const avatars = ['🦁', '🐵', '🦜', '🐸', '🐯', '🐘', '🦊', '🐼', '🦋', '🐢', '🦓', '🐨'];

  Future<void> _rename(BuildContext context, WidgetRef ref, UserProfile profile) async {
    final controller = TextEditingController(text: profile.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 16,
          decoration: const InputDecoration(hintText: 'Display name'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == profile.displayName) return;
    await ref.read(profileRepositoryProvider).updateProfile(profile.uid, displayName: trimmed);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authStateProvider).value;
    final profile = ref.watch(profileProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('PROFILE')),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: AppTheme.background(theme.brightness),
        child: SafeArea(
          child: profile == null
              ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      children: [
                        Center(
                          child: PopupMenuButton<String>(
                            tooltip: 'Change avatar',
                            onSelected: (a) => ref.read(profileRepositoryProvider).updateProfile(profile.uid, avatar: a),
                            itemBuilder: (_) => [
                              for (final a in avatars) PopupMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 26))),
                            ],
                            child: Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const RadialGradient(colors: [AppColors.jungleLight, AppColors.jungleDark]),
                                border: Border.all(color: AppColors.gold, width: 4),
                              ),
                              alignment: Alignment.center,
                              child: Text(profile.avatar, style: const TextStyle(fontSize: 54)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => _rename(context, ref, profile),
                            icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.gold),
                            label: Text(
                              profile.displayName,
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            user?.isOffline == true
                                ? 'Offline guest'
                                : profile.isGuest
                                    ? 'Guest account'
                                    : (user?.email ?? 'Signed in'),
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _StatsGrid(stats: profile.stats),
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
                          icon: const Icon(Icons.history_rounded),
                          label: const Text('Game history'),
                        ),
                        const SizedBox(height: 10),
                        if (profile.isGuest && ref.read(authServiceProvider).supportsGoogle)
                          ElevatedButton.icon(
                            onPressed: () async {
                              final ok = await ref.read(authControllerProvider.notifier).signInWithGoogle();
                              if (!context.mounted) return;
                              final err = ref.read(authControllerProvider).error;
                              if (!ok && err != null) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$err')));
                              }
                            },
                            icon: const Icon(Icons.link_rounded),
                            label: const Text('LINK GOOGLE ACCOUNT'),
                          ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: () async {
                            await ref.read(authControllerProvider.notifier).signOut();
                            if (!context.mounted) return;
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (_) => false,
                            );
                          },
                          icon: const Icon(Icons.logout_rounded, color: AppColors.sunset),
                          label: const Text('Sign out', style: TextStyle(color: AppColors.sunset)),
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

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final ProfileStats stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Games', '${stats.games}'),
      ('Wins', '${stats.wins}'),
      ('Win rate', '${(stats.winRate * 100).round()}%'),
      ('Rating', '${stats.rating}'),
      ('Streak', '${stats.winStreak}'),
      ('Best win', stats.bestWinTurns == null ? '—' : '${stats.bestWinTurns} turns'),
      ('Ladders', '${stats.ladders}'),
      ('Snakes', '${stats.snakes}'),
    ];
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.1,
      children: [
        for (final (label, value) in items)
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.gold)),
                ),
                Text(label, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
      ],
    );
  }
}
