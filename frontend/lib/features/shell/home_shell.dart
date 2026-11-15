import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../../widgets/sheet.dart';
import '../alerts/alerts_screen.dart';
import '../ask/ask_sheet.dart';
import '../customers/customers_screen.dart';
import '../growth/growth_screen.dart';
import '../home/home_screen.dart';
import '../settings/api_settings_sheet.dart';

/// Bottom-tab shell: Home, Customers, Alerts, Growth + a floating "Ask AI" button.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const _screens = <Widget>[HomeScreen(), CustomersScreen(), AlertsScreen(), GrowthScreen()];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(navIndexProvider);
    final summary = ref.watch(summaryProvider);
    final campaigns = ref.watch(campaignsProvider);

    final alertCount = summary.valueOrNull?.alertsCount ?? 0;
    final draftCount = campaigns.valueOrNull?.campaigns.where((c) => c.isDraft).length ?? 0;
    final offline = ref.watch(offlineProvider);
    final topInset = MediaQuery.paddingOf(context).top;

    // Home has a dark gradient header (light status-bar icons); other tabs follow the theme.
    final lightIcons = index == 0 || context.dark;
    final overlay = lightIcons ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        extendBody: false,
        body: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(anim),
                  child: child,
                ),
              ),
              child: KeyedSubtree(key: ValueKey(index), child: _screens[index]),
            ),
            // Keeps scrolled content from showing through the phone's status bar (clock, battery).
            if (index != 0 && topInset > 0)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: topInset,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [context.cs.surface, context.cs.surface.withValues(alpha: 0.0)],
                        stops: const [0.55, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            const _AutoRetry(),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 6,
              left: 16,
              right: 16,
              child: IgnorePointer(
                ignoring: !offline,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  offset: offline ? Offset.zero : const Offset(0, -1.8),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: offline ? 1 : 0,
                    child: _OfflineBanner(
                      onRetry: () => invalidateAll(ref.invalidate),
                      onSettings: () => showAppSheet(context, (_) => const ApiSettingsSheet()),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'ask-ai',
          onPressed: () => showAppSheet(context, (_) => const AskSheet(), full: true),
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('Ask AI'),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => ref.read(navIndexProvider.notifier).state = i,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard_rounded),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.people_alt_outlined),
              selectedIcon: Icon(Icons.people_alt_rounded),
              label: 'Customers',
            ),
            NavigationDestination(
              icon: Badge(
                label: Text('$alertCount'),
                isLabelVisible: alertCount > 0,
                child: const Icon(Icons.notifications_none_rounded),
              ),
              selectedIcon: Badge(
                label: Text('$alertCount'),
                isLabelVisible: alertCount > 0,
                child: const Icon(Icons.notifications_rounded),
              ),
              label: 'Warnings',
            ),
            NavigationDestination(
              icon: Badge(
                label: Text('$draftCount'),
                isLabelVisible: draftCount > 0,
                backgroundColor: Brand.amber,
                textColor: Brand.navy,
                child: const Icon(Icons.auto_awesome_outlined),
              ),
              selectedIcon: Badge(
                label: Text('$draftCount'),
                isLabelVisible: draftCount > 0,
                backgroundColor: Brand.amber,
                textColor: Brand.navy,
                child: const Icon(Icons.auto_awesome_rounded),
              ),
              label: 'Offers',
            ),
          ],
        ),
      ),
    );
  }
}

/// While the server is unreachable, quietly try again every few seconds so the app recovers
/// on its own (e.g. backend still starting, USB tunnel reconnecting) without a manual Retry.
class _AutoRetry extends ConsumerStatefulWidget {
  const _AutoRetry();

  @override
  ConsumerState<_AutoRetry> createState() => _AutoRetryState();
}

class _AutoRetryState extends ConsumerState<_AutoRetry> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    ref.listenManual<bool>(offlineProvider, (_, offline) => offline ? _start() : _stop(), fireImmediately: true);
  }

  void _start() {
    _timer ??= Timer.periodic(const Duration(seconds: 6), (_) {
      // Do not pile up requests while one is still in flight.
      if (!ref.read(summaryProvider).isLoading) invalidateAll(ref.invalidate);
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.onRetry, required this.onSettings});
  final VoidCallback onRetry, onSettings;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Brand.navy,
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: Color(0xFFFF8A8E), size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('No connection. Trying again…',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5)),
            ),
            TextButton(onPressed: onSettings, child: const Text('Settings')),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
