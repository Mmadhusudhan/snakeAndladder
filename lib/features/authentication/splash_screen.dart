import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/settings_providers.dart';
import '../home/home_screen.dart';
import '../onboarding/onboarding_screen.dart';
import 'login_screen.dart';

/// Starts Firebase, waits for the auth state, then routes to Login or Home.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _routed = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _route(Widget screen) {
    if (_routed || !mounted) return;
    _routed = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => screen,
        transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(firebaseStatusProvider);
    final auth = ref.watch(authStateProvider);
    final settings = ref.watch(settingsProvider);

    if (status.hasValue && settings.loaded) {
      auth.whenData((user) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (user != null) ref.read(profileRepositoryProvider).ensureProfile(user);
          if (!settings.onboardingDone) {
            _route(const OnboardingScreen());
          } else if (user != null) {
            _route(const HomeScreen());
          } else {
            _route(const LoginScreen());
          }
        });
      });
      if (auth.hasError) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _route(const LoginScreen()));
      }
    }

    final brightness = Theme.of(context).brightness;
    return Scaffold(
      body: Container(
        decoration: AppTheme.background(brightness),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) => Transform.scale(
                  scale: 1 + 0.06 * _pulse.value,
                  child: child,
                ),
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [AppColors.jungleLight, AppColors.jungleMid, AppColors.jungleDark],
                    ),
                    border: Border.all(color: AppColors.gold, width: 4),
                    boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.45), blurRadius: 40)],
                  ),
                  alignment: Alignment.center,
                  child: const Text('🐍🎲', style: TextStyle(fontSize: 60)),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'SNAKES & LADDERS',
                style: TextStyle(color: AppColors.gold, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 3),
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.gold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
