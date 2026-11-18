import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/audio_service.dart';
import '../../providers/app_providers.dart';
import '../../providers/game_providers.dart';
import '../../providers/settings_providers.dart';
import '../settings/settings_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../multiplayer/online_lobby_screen.dart';
import '../profile/profile_screen.dart';
import 'game_setup_screen.dart';
import 'rules_dialog.dart';

/// Landing screen with the game modes available in this build.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, WidgetRef ref, GameMode mode) {
    _tap(ref);
    ref.read(gameSetupProvider.notifier).setMode(mode, playerCount: 2);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GameSetupScreen()),
    );
  }

  /// Click + (on web) the first user gesture that may start the music.
  static void _tap(WidgetRef ref) {
    final audio = ref.read(audioServiceProvider);
    audio.play(Sfx.click);
    audio.startMusic();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).value;
    // Start the music loop once the home screen is up (no-op if disabled).
    ref.listen(settingsProvider.select((s) => s.loaded), (_, loaded) {
      if (loaded) ref.read(audioServiceProvider).startMusic();
    });
    if (ref.read(settingsProvider).loaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(audioServiceProvider).startMusic());
    }
    return Scaffold(
      body: Container(
        decoration: AppTheme.background(brightness),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                left: 12,
                right: 12,
                top: 8,
                child: Row(
                  children: [
                    _ProfileChip(
                      avatar: profile?.avatar ?? '🙂',
                      name: profile?.displayName ?? 'Guest',
                      rating: profile?.stats.rating,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Settings',
                      onPressed: () {
                        _tap(ref);
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                      },
                      icon: const Icon(Icons.settings_rounded, color: AppColors.gold, size: 28),
                    ),
                    IconButton(
                      tooltip: 'Leaderboard',
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
                      icon: const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 30),
                    ),
                  ],
                ),
              ),
              Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 48),
                    const _Logo(),
                    const SizedBox(height: 12),
                    Text(
                      'SNAKES & LADDERS',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                    Text(
                      'Jungle Edition',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.jungleLight,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 36),
                    _ModeButton(
                      icon: Icons.smart_toy_rounded,
                      title: 'Play vs Computer',
                      subtitle: 'You against up to 3 jungle bots',
                      onTap: () => _open(context, ref, GameMode.vsComputer),
                    ),
                    const SizedBox(height: 14),
                    _ModeButton(
                      icon: Icons.groups_rounded,
                      title: 'Local Multiplayer',
                      subtitle: '2 - 4 players on one device',
                      onTap: () => _open(context, ref, GameMode.localMultiplayer),
                    ),
                    const SizedBox(height: 14),
                    _ModeButton(
                      icon: Icons.public_rounded,
                      title: 'Play Online',
                      subtitle: 'Quick match or private room with a code',
                      onTap: () {
                        _tap(ref);
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OnlineLobbyScreen()));
                      },
                    ),
                    const SizedBox(height: 14),
                    _ModeButton(
                      icon: Icons.school_rounded,
                      title: 'Practice',
                      subtitle: 'Relaxed rules, no exact roll needed',
                      onTap: () => _open(context, ref, GameMode.practice),
                    ),
                    const SizedBox(height: 28),
                    TextButton.icon(
                      onPressed: () => showRulesDialog(context),
                      icon: const Icon(Icons.help_outline_rounded, color: AppColors.gold),
                      label: const Text(
                        'How to play',
                        style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({required this.avatar, required this.name, required this.rating, required this.onTap});

  final String avatar;
  final String name;
  final int? rating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.jungleMid),
                alignment: Alignment.center,
                child: Text(avatar, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                  if (rating != null)
                    Text('$rating pts', style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [AppColors.jungleLight, AppColors.jungleMid, AppColors.jungleDark],
        ),
        border: Border.all(color: AppColors.gold, width: 4),
        boxShadow: [
          BoxShadow(color: AppColors.gold.withValues(alpha: 0.4), blurRadius: 30),
        ],
      ),
      alignment: Alignment.center,
      child: const Text('🐍🎲', style: TextStyle(fontSize: 56)),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: isDark
                  ? [AppColors.jungleMid.withValues(alpha: 0.9), AppColors.jungleDark]
                  : [Colors.white, const Color(0xFFE2F2D6)],
            ),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.7), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.gold),
                child: Icon(icon, color: AppColors.jungleDeep, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.gold),
            ],
          ),
        ),
      ),
    );
  }
}
