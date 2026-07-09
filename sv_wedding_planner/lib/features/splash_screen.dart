import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../state/providers.dart';
import '../widgets/brand.dart';
import 'home_shell.dart';
import 'onboarding_screen.dart';

/// Branded splash shown briefly on launch, then routes to onboarding (first
/// run) or the home shell.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    final onboarded = ref.read(localStoreProvider).onboarded;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => onboarded ? const HomeShell() : const OnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.brandGreenDeep,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLogo(size: 160, radius: 36),
            const SizedBox(height: 28),
            Text(
              'SV WEDDING PLANNER',
              style: TextStyle(
                color: AppTheme.goldLight,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Plan beautifully. Celebrate forever.',
              style: TextStyle(
                color: AppTheme.gold.withOpacity(0.8),
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppTheme.gold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
