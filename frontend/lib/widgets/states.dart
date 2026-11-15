import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/api_client.dart';
import '../core/theme.dart';

/// Shimmering placeholder block shown while data loads.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.width, this.height = 16, this.radius = 12});
  final double? width;
  final double height, radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.dark ? const Color(0xFF1B2940) : const Color(0xFFE4EAF2),
        borderRadius: BorderRadius.circular(radius),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1300.ms, color: context.dark ? const Color(0x22FFFFFF) : const Color(0x99FFFFFF));
  }
}

/// A card-shaped skeleton with a few lines.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.height = 110});
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: context.hairline),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 90, height: 12),
            SizedBox(height: 14),
            Skeleton(width: 150, height: 24),
            Spacer(),
            Skeleton(height: 10),
          ],
        ),
      );
}

/// Friendly error with retry. Explains network problems in plain words.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry, this.onSettings, this.compact = false});
  final Object error;
  final VoidCallback onRetry;
  final VoidCallback? onSettings;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final api = error is ApiException ? error as ApiException : null;
    final network = api?.isNetwork ?? false;
    final message = api?.message ?? 'Something went wrong. Please try again.';
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 56 : 84,
              height: compact ? 56 : 84,
              decoration: BoxDecoration(color: Brand.danger.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(network ? Icons.cloud_off_rounded : Icons.error_outline_rounded,
                  color: Brand.danger, size: compact ? 28 : 40),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
            SizedBox(height: compact ? 10 : 18),
            Text(network ? "Can't connect" : 'Something went wrong', style: context.tt.titleMedium),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: context.muted, height: 1.4)),
            if (network && !compact) ...[
              const SizedBox(height: 6),
              Text('Your data is safe. The app will keep trying and reconnect by itself.',
                  textAlign: TextAlign.center, style: TextStyle(color: context.muted, fontSize: 12.5, height: 1.4)),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(130, 44)),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try again'),
                ),
                if (network && onSettings != null)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(130, 44)),
                    onPressed: onSettings,
                    icon: const Icon(Icons.settings_ethernet_rounded, size: 18),
                    label: const Text('Connection settings'),
                  ),
              ],
            ),
          ],
        ).animate().fadeIn(duration: 300.ms),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.color = Brand.primary,
  });

  final IconData icon;
  final String title, subtitle;
  final Widget? action;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, size: 44, color: color),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(1, 1), end: const Offset(1.06, 1.06), duration: 1600.ms, curve: Curves.easeInOut),
            const SizedBox(height: 20),
            Text(title, style: context.tt.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: context.muted, height: 1.45)),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0),
      ),
    );
  }
}
