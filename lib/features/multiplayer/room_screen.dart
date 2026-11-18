import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/online_room.dart';
import '../../providers/app_providers.dart';
import '../../providers/online_providers.dart';
import 'online_game_screen.dart';

/// Waiting room: invite code, seats, start (host) and leave.
class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  bool _navigated = false;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$e'.replaceFirst(RegExp(r'^(ApiException|StateError|Bad state): ?'), '')),
        backgroundColor: AppColors.sunset,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roomAsync = ref.watch(roomProvider(widget.roomId));
    final user = ref.watch(authStateProvider).value;
    final service = ref.read(roomServiceProvider);

    ref.listen<AsyncValue<OnlineRoom?>>(roomProvider(widget.roomId), (prev, next) {
      final room = next.value;
      if (room != null && (room.isPlaying || room.isFinished) && !_navigated) {
        _navigated = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => OnlineGameScreen(roomId: widget.roomId)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('ROOM')),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: AppTheme.background(theme.brightness),
        child: SafeArea(
          child: roomAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
            error: (e, _) => Center(child: Text('Could not load room: $e')),
            data: (room) {
              if (room == null) return const Center(child: Text('This room no longer exists.'));
              final isHost = user != null && room.isHost(user.uid);
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    children: [
                      Text('INVITE CODE', textAlign: TextAlign.center, style: theme.textTheme.labelLarge?.copyWith(color: AppColors.gold, letterSpacing: 2, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Center(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            await Clipboard.setData(ClipboardData(text: room.code));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied')));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.gold, width: 2),
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(room.code, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 6, color: AppColors.gold)),
                                const SizedBox(width: 10),
                                const Icon(Icons.copy_rounded, color: AppColors.gold),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Share it with friends to join', textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                      const SizedBox(height: 24),
                      Text('PLAYERS ${room.seats.length}/${room.maxPlayers}', style: theme.textTheme.labelLarge?.copyWith(color: AppColors.gold, letterSpacing: 2, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      for (final s in room.seats)
                        Card(
                          child: ListTile(
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.players[s.colorIndex % AppColors.players.length], border: Border.all(color: Colors.white, width: 2)),
                              alignment: Alignment.center,
                              child: Text(s.avatar, style: const TextStyle(fontSize: 20)),
                            ),
                            title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text(s.uid == room.hostUid ? 'Host' : 'Ready'),
                            trailing: user != null && s.uid == user.uid ? const Text('You', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)) : null,
                          ),
                        ),
                      for (var i = room.seats.length; i < room.maxPlayers; i++)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.hourglass_top_rounded),
                            title: Text('Waiting for player…', style: TextStyle(color: theme.hintColor)),
                          ),
                        ),
                      const SizedBox(height: 22),
                      if (isHost)
                        ElevatedButton.icon(
                          onPressed: _busy || !room.canStart ? null : () => _run(() => service.startRoom(room.id)),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(room.canStart ? 'START GAME' : 'WAITING FOR PLAYERS'),
                        )
                      else
                        Text('Waiting for the host to start…', textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                  await service.leaveRoom(room.id);
                                  if (context.mounted) Navigator.of(context).pop();
                                }),
                        icon: const Icon(Icons.exit_to_app_rounded),
                        label: const Text('Leave room'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
