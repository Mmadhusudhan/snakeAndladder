import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/settings_providers.dart';
import '../authentication/login_screen.dart';
import '../home/home_screen.dart';

/// Three-page introduction shown on first launch (and replayable).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.replay = false});

  /// Opened from settings: finishing just pops instead of routing.
  final bool replay;

  static const pages = [
    (emoji: '🎲', title: 'Roll & race', body: 'Tap the dice on your turn and race your token from 1 to 100. Roll a six and you go again!'),
    (emoji: '🪜', title: 'Climb ladders', body: 'Land at the foot of a ladder to climb straight up. Land on a snake\'s head and it swallows you down to its tail.'),
    (emoji: '🌍', title: 'Play anyone', body: 'Beat the jungle bots, pass the phone around, or play online with friends using a room code.'),
  ];

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(settingsProvider.notifier).completeOnboarding();
    if (!mounted) return;
    if (widget.replay) {
      Navigator.of(context).pop();
      return;
    }
    final signedIn = ref.read(authStateProvider).value != null;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => signedIn ? const HomeScreen() : const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = _page == OnboardingScreen.pages.length - 1;
    return Scaffold(
      body: Container(
        decoration: AppTheme.background(theme.brightness),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Skip', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: OnboardingScreen.pages.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) {
                    final p = OnboardingScreen.pages[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TweenAnimationBuilder<double>(
                            key: ValueKey(i),
                            tween: Tween(begin: 0.6, end: 1),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutBack,
                            builder: (_, v, child) => Transform.scale(scale: v, child: child),
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const RadialGradient(colors: [AppColors.jungleLight, AppColors.jungleMid, AppColors.jungleDark]),
                                border: Border.all(color: AppColors.gold, width: 4),
                                boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 30)],
                              ),
                              alignment: Alignment.center,
                              child: Text(p.emoji, style: const TextStyle(fontSize: 72)),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(p.title, textAlign: TextAlign.center, style: theme.textTheme.headlineMedium?.copyWith(color: AppColors.gold, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 12),
                          Text(p.body, textAlign: TextAlign.center, style: theme.textTheme.titleMedium?.copyWith(height: 1.4)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < OnboardingScreen.pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page ? AppColors.gold : AppColors.gold.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 20, 32, 28),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: last
                        ? _finish
                        : () => _controller.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOut),
                    child: Text(last ? "LET'S PLAY" : 'NEXT'),
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
