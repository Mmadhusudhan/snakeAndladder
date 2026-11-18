import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../home/home_screen.dart';

/// Google sign-in, guest sign-in, and an explicit offline mode when Firebase
/// is not configured.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  Future<void> _go(BuildContext context, WidgetRef ref, Future<bool> Function() action) async {
    final ok = await action();
    if (!context.mounted) return;
    if (ok) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
      return;
    }
    final error = ref.read(authControllerProvider).error;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: AppColors.sunset),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status = ref.watch(firebaseStatusProvider).value;
    final online = status?.available ?? false;
    final busy = ref.watch(authControllerProvider).isLoading;
    final controller = ref.read(authControllerProvider.notifier);

    return Scaffold(
      body: Container(
        decoration: AppTheme.background(theme.brightness),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🐍🎲', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 8),
                    Text(
                      'Welcome to the jungle',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(color: AppColors.gold, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      online
                          ? 'Sign in to keep your stats and climb the leaderboard.'
                          : 'Playing offline: stats stay on this device until Firebase is set up.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                    ),
                    const SizedBox(height: 32),
                    if (online) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: busy ? null : () => _go(context, ref, controller.signInWithGoogle),
                          icon: const Icon(Icons.login_rounded),
                          label: const Text('CONTINUE WITH GOOGLE'),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : () => _go(context, ref, controller.signInAsGuest),
                        icon: const Icon(Icons.person_outline_rounded),
                        label: Text(online ? 'PLAY AS GUEST' : 'PLAY OFFLINE'),
                      ),
                    ),
                    if (busy) ...[
                      const SizedBox(height: 20),
                      const CircularProgressIndicator(color: AppColors.gold),
                    ],
                    if (!online && status?.reason != null) ...[
                      const SizedBox(height: 28),
                      Text(
                        status!.reason!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
