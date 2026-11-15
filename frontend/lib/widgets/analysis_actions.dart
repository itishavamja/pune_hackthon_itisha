import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../providers/providers.dart';
import 'app_card.dart';
import 'toast.dart';

/// Runs the full pipeline (POST /analyze) and reports the outcome.
Future<void> runAnalysis(BuildContext context, WidgetRef ref, {bool goToGrowth = true}) async {
  final result = await ref.read(analysisProvider.notifier).run();
  if (!context.mounted) return;
  if (result == null) {
    final err = ref.read(analysisProvider).error;
    if (err != null) showToast(context, err.message, kind: ToastKind.error);
    return;
  }
  final n = result.draftCount;
  showToast(
    context,
    result.usedAi
        ? 'Done! $n offers are ready. The AI wrote them for you to review.'
        : 'Done! $n offers are ready for you to review.',
    kind: ToastKind.success,
  );
  if (goToGrowth) ref.read(navIndexProvider.notifier).state = 3;
}

/// Big call-to-action card shown on the dashboard.
class AnalysisCta extends ConsumerWidget {
  const AnalysisCta({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = ref.watch(analysisProvider.select((s) => s.running));
    final language = ref.watch(languageProvider);
    return AppCard(
      padding: EdgeInsets.zero,
      gradient: Brand.ctaGradient,
      borderColor: Colors.transparent,
      onTap: running ? null : () => runAnalysis(context, ref),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: running
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 26)
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(begin: const Offset(0.92, 0.92), end: const Offset(1.1, 1.1), duration: 1100.ms),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    running ? 'Checking your shop…' : 'Check my shop',
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    running
                        ? 'Looking at your sales and customers, then writing offers'
                        : 'Find out why sales are low and get offers written for you in $language',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 12.5, height: 1.35),
                  ),
                ],
              ),
            ),
            if (!running) const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

/// Compact button version for other screens.
class RunAnalysisButton extends ConsumerWidget {
  const RunAnalysisButton({super.key, this.label = 'Check my shop', this.goToGrowth = false});
  final String label;
  final bool goToGrowth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = ref.watch(analysisProvider.select((s) => s.running));
    return FilledButton.icon(
      onPressed: running ? null : () => runAnalysis(context, ref, goToGrowth: goToGrowth),
      icon: running
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4))
          : const Icon(Icons.auto_awesome_rounded, size: 19),
      label: Text(running ? 'Checking…' : label),
    );
  }
}
