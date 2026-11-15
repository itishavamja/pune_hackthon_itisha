import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/shell/home_shell.dart';
import 'providers/providers.dart';

/// Lets mouse / trackpad drag scroll views too (needed for web and desktop testing).
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class DukaanApp extends StatelessWidget {
  const DukaanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dukaan360',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      scrollBehavior: const AppScrollBehavior(),
      builder: (context, child) => MobileFrame(child: child ?? const SizedBox.shrink()),
      home: const SplashGate(),
    );
  }
}

/// On a phone the app fills the screen. On a wide screen (web / desktop) it is shown inside a
/// phone-sized frame so the demo looks the same everywhere.
class MobileFrame extends StatelessWidget {
  const MobileFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 600) return child;
      const w = 410.0;
      final h = (c.maxHeight - 32).clamp(520.0, 900.0);
      final dark = Theme.of(context).brightness == Brightness.dark;
      final mq = MediaQuery.of(context);
      return ColoredBox(
        color: dark ? const Color(0xFF05090F) : const Color(0xFFDCE4EE),
        child: Center(
          child: Container(
            width: w,
            height: h,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(38),
              border: Border.all(color: dark ? const Color(0xFF223049) : Colors.white, width: 6),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 40, offset: Offset(0, 16))],
            ),
            child: MediaQuery(
              data: mq.copyWith(size: Size(w - 12, h - 12), padding: EdgeInsets.zero, viewPadding: EdgeInsets.zero),
              child: child,
            ),
          ),
        ),
      );
    });
  }
}

/// Short animated logo screen, then (first launch only) a 3-screen welcome, then the app.
class SplashGate extends ConsumerStatefulWidget {
  const SplashGate({super.key, this.duration = const Duration(milliseconds: 1700)});
  final Duration duration;

  @override
  ConsumerState<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends ConsumerState<SplashGate> {
  bool _splashDone = false;
  late bool _onboarded = ref.read(sharedPrefsProvider).getBool(kPrefOnboarded) ?? false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.duration, () {
      if (mounted) setState(() => _splashDone = true);
    });
  }

  void _finishOnboarding() {
    ref.read(sharedPrefsProvider).setBool(kPrefOnboarded, true);
    setState(() => _onboarded = true);
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (!_splashDone) {
      child = const _Splash(key: ValueKey('splash'));
    } else if (!_onboarded) {
      child = OnboardingScreen(key: const ValueKey('welcome'), onDone: _finishOnboarding);
    } else {
      child = const HomeShell(key: ValueKey('shell'));
    }
    return AnimatedSwitcher(duration: const Duration(milliseconds: 500), child: child);
  }
}

class _Splash extends StatelessWidget {
  const _Splash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: Brand.heroGradient),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white24),
              ),
              child: const Text('360', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
            ).animate().scale(begin: const Offset(0.5, 0.5), duration: 650.ms, curve: Curves.easeOutBack).fadeIn(duration: 400.ms),
            const SizedBox(height: 22),
            const Text('Dukaan360',
                    style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.6))
                .animate()
                .fadeIn(delay: 350.ms, duration: 450.ms)
                .slideY(begin: 0.4, end: 0, delay: 350.ms, duration: 450.ms),
            const SizedBox(height: 8),
            const Text('Predict before you lose', style: TextStyle(color: Colors.white70, fontSize: 15))
                .animate()
                .fadeIn(delay: 650.ms, duration: 450.ms),
          ],
        ),
      ),
    );
  }
}
