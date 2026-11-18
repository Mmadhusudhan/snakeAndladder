import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/services/audio_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/settings_providers.dart';
import '../home/rules_screen.dart';
import '../onboarding/onboarding_screen.dart';

/// Sound, music, vibration, theme, rules and tutorial.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final audio = ref.read(audioServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('SETTINGS')),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: AppTheme.background(theme.brightness),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  _Section('Audio'),
                  _Switch(
                    icon: Icons.volume_up_rounded,
                    title: 'Sound effects',
                    subtitle: 'Dice, snakes, ladders, wins',
                    value: settings.sound,
                    onChanged: (v) {
                      notifier.setSound(v);
                      if (v) audio.play(Sfx.click);
                    },
                  ),
                  _Switch(
                    icon: Icons.music_note_rounded,
                    title: 'Music',
                    subtitle: 'Jungle groove in the background',
                    value: settings.music,
                    onChanged: notifier.setMusic,
                  ),
                  _Switch(
                    icon: Icons.vibration_rounded,
                    title: 'Vibration',
                    subtitle: 'Haptic feedback on moves',
                    value: settings.haptics,
                    onChanged: notifier.setHaptics,
                  ),
                  const SizedBox(height: 16),
                  _Section('Appearance'),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_rounded)),
                      ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_rounded)),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_rounded)),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (s) => notifier.setThemeMode(s.first),
                  ),
                  const SizedBox(height: 24),
                  _Section('Help'),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.menu_book_rounded, color: AppColors.gold),
                          title: const Text('How to play', style: TextStyle(fontWeight: FontWeight.w700)),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RulesScreen())),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.replay_rounded, color: AppColors.gold),
                          title: const Text('Replay the intro', style: TextStyle(fontWeight: FontWeight.w700)),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const OnboardingScreen(replay: true)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Snakes & Ladders · Jungle Edition · v1.0.0',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
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

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 8),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.gold, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
      );
}

class _Switch extends StatelessWidget {
  const _Switch({required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged});

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: SwitchListTile.adaptive(
          secondary: Icon(icon, color: AppColors.gold),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle),
          value: value,
          activeThumbColor: AppColors.gold,
          onChanged: onChanged,
        ),
      );
}
