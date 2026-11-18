import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/game_providers.dart';
import '../game/models/bot_personality.dart';
import '../game/screens/game_screen.dart';

/// Choose player count, names, avatars and rules before starting.
class GameSetupScreen extends ConsumerWidget {
  const GameSetupScreen({super.key});

  static const avatars = ['🦁', '🐵', '🦜', '🐸', '🐯', '🐘', '🦊', '🐼', '🦋', '🐢'];

  String _title(GameMode mode) => switch (mode) {
        GameMode.vsComputer => 'Play vs Computer',
        GameMode.localMultiplayer => 'Local Multiplayer',
        GameMode.practice => 'Practice',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(gameSetupProvider);
    final notifier = ref.read(gameSetupProvider.notifier);
    final theme = Theme.of(context);
    final rules = setup.rules;
    final isPractice = setup.mode == GameMode.practice;

    return Scaffold(
      appBar: AppBar(title: Text(_title(setup.mode))),
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
                  _SectionTitle('Players'),
                  Wrap(
                    spacing: 10,
                    children: [
                      for (final n in [2, 3, 4])
                        ChoiceChip(
                          label: Text('$n players'),
                          selected: setup.players.length == n,
                          selectedColor: AppColors.gold,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: setup.players.length == n ? AppColors.jungleDeep : null,
                          ),
                          onSelected: (_) => notifier.setPlayerCount(n),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final (i, p) in setup.players.indexed)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            _ColorPicker(
                              selected: p.colorIndex,
                              onSelected: (c) => notifier.setColor(i, c),
                            ),
                            const SizedBox(width: 10),
                            PopupMenuButton<String>(
                              tooltip: 'Choose avatar',
                              enabled: !p.isComputer,
                              onSelected: (a) => notifier.setAvatar(i, a),
                              itemBuilder: (_) => [
                                for (final a in avatars)
                                  PopupMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 24))),
                              ],
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.players[p.colorIndex],
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                alignment: Alignment.center,
                                child: Text(p.avatar, style: const TextStyle(fontSize: 22)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: p.isComputer
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(p.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                            const SizedBox(width: 6),
                                            Icon(Icons.smart_toy_rounded, size: 18, color: theme.hintColor),
                                          ],
                                        ),
                                        Text(
                                          'Computer · ${(p.level ?? setup.botLevel).label}',
                                          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                                        ),
                                      ],
                                    )
                                  : TextFormField(
                                      key: ValueKey('name-${p.id}-${setup.mode}'),
                                      initialValue: p.name,
                                      maxLength: 14,
                                      decoration: const InputDecoration(
                                        counterText: '',
                                        isDense: true,
                                        border: UnderlineInputBorder(),
                                        hintText: 'Player name',
                                      ),
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                      onChanged: (v) => notifier.renamePlayer(i, v),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (setup.hasComputer) ...[
                    const SizedBox(height: 20),
                    _SectionTitle('Computer strength'),
                    Wrap(
                      spacing: 10,
                      children: [
                        for (final level in ComputerLevel.values)
                          ChoiceChip(
                            label: Text(level.label),
                            selected: setup.botLevel == level,
                            selectedColor: AppColors.gold,
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: setup.botLevel == level ? AppColors.jungleDeep : null,
                            ),
                            onSelected: (_) => notifier.setBotLevel(level),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(setup.botLevel.description, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _SectionTitle('Rules'),
                  _RuleSwitch(
                    title: 'Exact roll to win',
                    subtitle: 'Overshooting 100 wastes the turn',
                    value: rules.exactRollToWin && !isPractice,
                    onChanged: isPractice ? null : (v) => notifier.setRules(rules.copyWith(exactRollToWin: v)),
                  ),
                  _RuleSwitch(
                    title: 'Extra turn on six',
                    value: rules.extraTurnOnSix,
                    onChanged: (v) => notifier.setRules(rules.copyWith(extraTurnOnSix: v)),
                  ),
                  _RuleSwitch(
                    title: 'Three sixes forfeit the turn',
                    value: rules.maxConsecutiveSixes > 0,
                    onChanged: (v) => notifier.setRules(rules.copyWith(maxConsecutiveSixes: v ? 3 : 0)),
                  ),
                  _RuleSwitch(
                    title: 'Need a six to start',
                    value: rules.needSixToStart,
                    onChanged: (v) => notifier.setRules(rules.copyWith(needSixToStart: v)),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (isPractice) {
                        notifier.setRules(rules.copyWith(exactRollToWin: false));
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const GameScreen()),
                      );
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                    label: const Text('START GAME'),
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

/// Four colour dots; tapping one takes that colour (swapping if needed).
class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in [
          [0, 1],
          [2, 3]
        ])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in row)
                GestureDetector(
                  onTap: () => onSelected(c),
                  child: Semantics(
                    label: 'Colour ${c + 1}',
                    selected: c == selected,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.players[c],
                        border: Border.all(
                          color: c == selected ? AppColors.gold : Colors.white24,
                          width: c == selected ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.gold,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
      ),
    );
  }
}

class _RuleSwitch extends StatelessWidget {
  const _RuleSwitch({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      activeThumbColor: AppColors.gold,
      onChanged: onChanged,
    );
  }
}
