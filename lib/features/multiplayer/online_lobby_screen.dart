import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/online_providers.dart';
import 'online_game_screen.dart';
import 'room_screen.dart';

/// Entry to online play: quick match, private room, join by code.
class OnlineLobbyScreen extends ConsumerStatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  ConsumerState<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends ConsumerState<OnlineLobbyScreen> {
  final _codeController = TextEditingController();
  int _tableSize = 2;
  bool _busy = false;
  bool _searching = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendly(e)), backgroundColor: AppColors.sunset),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _friendly(Object e) =>
      '$e'.replaceFirst(RegExp(r'^(ApiException|StateError|Bad state): ?'), '').replaceFirst(RegExp(r'^API \d+: '), '');

  void _openRoom(String roomId) {
    final room = ref.read(roomServiceProvider);
    room.watchRoom(roomId).first.then((r) {
      if (!mounted) return;
      final playing = r?.isPlaying == true || r?.isFinished == true;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => playing ? OnlineGameScreen(roomId: roomId) : RoomScreen(roomId: roomId),
      ));
    });
  }

  Future<void> _quickMatch() => _run(() async {
        final result = await ref.read(roomServiceProvider).joinQueue(maxPlayers: _tableSize);
        if (!mounted) return;
        if (result.roomId != null) {
          _openRoom(result.roomId!);
        } else {
          setState(() => _searching = true);
        }
      });

  Future<void> _cancelSearch() => _run(() async {
        await ref.read(roomServiceProvider).leaveQueue();
        if (mounted) setState(() => _searching = false);
      });

  Future<void> _create() => _run(() async {
        final room = await ref.read(roomServiceProvider).createRoom(maxPlayers: _tableSize);
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoomScreen(roomId: room.id)));
      });

  Future<void> _join() => _run(() async {
        final code = _codeController.text.trim().toUpperCase();
        if (code.length != 6) throw StateError('Enter the 6-character code');
        final room = await ref.read(roomServiceProvider).joinByCode(code);
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoomScreen(roomId: room.id)));
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = ref.watch(roomServiceProvider);
    final myRoom = ref.watch(myRoomIdProvider).value;

    // A queued player gets matched: the server assigns the room.
    ref.listen<AsyncValue<String?>>(myRoomIdProvider, (prev, next) {
      final id = next.value;
      if (_searching && id != null) {
        setState(() => _searching = false);
        _openRoom(id);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('PLAY ONLINE')),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: AppTheme.background(theme.brightness),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  if (service.modeNote case final note?)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.sunset.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.sunset.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.wifi_off_rounded, color: AppColors.sunset),
                          const SizedBox(width: 10),
                          Expanded(child: Text(note, style: theme.textTheme.bodySmall)),
                        ],
                      ),
                    ),
                  if (myRoom != null)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.meeting_room_rounded, color: AppColors.gold),
                        title: const Text('You have a game in progress', style: TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text('Tap to rejoin'),
                        onTap: () => _openRoom(myRoom),
                      ),
                    ),
                  Text('TABLE SIZE', style: theme.textTheme.labelLarge?.copyWith(color: AppColors.gold, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: [
                      for (final n in [2, 3, 4])
                        ChoiceChip(
                          label: Text('$n players'),
                          selected: _tableSize == n,
                          selectedColor: AppColors.gold,
                          labelStyle: TextStyle(fontWeight: FontWeight.w700, color: _tableSize == n ? AppColors.jungleDeep : null),
                          onSelected: (_) => setState(() => _tableSize = n),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  if (_searching)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            const CircularProgressIndicator(color: AppColors.gold),
                            const SizedBox(height: 12),
                            Text('Looking for $_tableSize players…', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 10),
                            OutlinedButton(onPressed: _busy ? null : _cancelSearch, child: const Text('Cancel')),
                          ],
                        ),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _busy ? null : _quickMatch,
                      icon: const Icon(Icons.bolt_rounded),
                      label: const Text('QUICK MATCH'),
                    ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _busy || _searching ? null : _create,
                    icon: const Icon(Icons.add_home_rounded),
                    label: const Text('CREATE PRIVATE ROOM'),
                  ),
                  const SizedBox(height: 26),
                  Text('JOIN WITH CODE', style: theme.textTheme.labelLarge?.copyWith(color: AppColors.gold, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 6,
                          decoration: const InputDecoration(counterText: '', hintText: 'ABC123', border: OutlineInputBorder()),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 4),
                          onSubmitted: (_) => _join(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(onPressed: _busy || _searching ? null : _join, child: const Text('JOIN')),
                    ],
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
