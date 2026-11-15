import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/analysis_actions.dart';
import '../../widgets/app_card.dart';
import '../../widgets/chips.dart';
import '../../widgets/sheet.dart';
import '../../widgets/states.dart';
import '../settings/api_settings_sheet.dart';

IconData _alertIcon(String type) => switch (type) {
      'sales_decline' => Icons.trending_down_rounded,
      'customer_churn' => Icons.person_off_rounded,
      'unusual_transaction' => Icons.report_problem_rounded,
      'abnormal_transaction_count' => Icons.bar_chart_rounded,
      'unusual_revenue_change' => Icons.show_chart_rounded,
      _ => Icons.notifications_rounded,
    };

String _metric(AlertItem a) {
  final v = a.metricValue;
  if (v == null || v.isEmpty) return '';
  final n = double.tryParse(v);
  if (n != null && (a.type == 'unusual_transaction' || a.type == 'unusual_revenue_change')) return money(n);
  return v;
}

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(alertsProvider);
    final sev = ref.watch(alertSeverityProvider);
    final top = MediaQuery.paddingOf(context).top;

    Widget body = alerts.when(
      loading: () => const SliverPadding(
        padding: EdgeInsets.all(16),
        sliver: SliverToBoxAdapter(
          child: Column(children: [SkeletonCard(height: 120), SizedBox(height: 12), SkeletonCard(height: 120), SizedBox(height: 12), SkeletonCard(height: 120)]),
        ),
      ),
      error: (e, _) => SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorView(
          error: e,
          onRetry: () => ref.invalidate(alertsProvider),
          onSettings: () => showAppSheet(context, (_) => const ApiSettingsSheet()),
        ),
      ),
      data: (page) {
        if (page.alerts.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: sev == null ? Icons.shield_moon_rounded : Icons.filter_alt_off_rounded,
              color: sev == null ? Brand.primary : Brand.info,
              title: sev == null ? 'No warnings yet' : 'No "${severityLabel(sev)}" warnings',
              subtitle: sev == null
                  ? 'Tap "Check my shop" and Dukaan360 will look for problems in your sales, customers and payments.'
                  : 'Nothing in this group right now.',
              action: sev == null ? const SizedBox(width: 220, child: RunAnalysisButton()) : null,
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          sliver: SliverList.builder(
            itemCount: page.alerts.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AlertCard(alert: page.alerts[i])
                  .animate()
                  .fadeIn(delay: (i * 70).ms, duration: 380.ms)
                  .slideY(begin: 0.1, end: 0, delay: (i * 70).ms, duration: 380.ms, curve: Curves.easeOutCubic),
            ),
          ),
        );
      },
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(alertsProvider);
        try {
          await ref.read(alertsProvider.future);
        } catch (_) {}
      },
      edgeOffset: top + 40,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, top + 18, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Warnings', style: context.tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Things that need your attention. The most serious are at the top.',
                      style: TextStyle(color: context.muted, fontSize: 13.5, height: 1.35)),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final f in const [null, 'HIGH', 'MEDIUM', 'LOW']) ...[
                          FilterPill(
                            label: f == null ? 'All' : severityLabel(f),
                            selected: sev == f,
                            onTap: () => ref.read(alertSeverityProvider.notifier).state = f,
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          body,
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});
  final AlertItem alert;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(alert.severity);
    final metric = _metric(alert);
    return AppCard(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(22)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconBadge(icon: _alertIcon(alert.type), color: color, size: 40)
                            .animate(
                              autoPlay: alert.severity == 'HIGH',
                              onPlay: (c) => c.repeat(reverse: true),
                            )
                            .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 900.ms),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(alert.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, height: 1.25)),
                              const SizedBox(height: 6),
                              Text(cleanText(alert.description), style: TextStyle(color: context.muted, fontSize: 13, height: 1.42)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (alertAdvice(alert.type) != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lightbulb_rounded, size: 17, color: color),
                            const SizedBox(width: 8),
                            Expanded(child: Text(alertAdvice(alert.type)!, style: const TextStyle(fontSize: 12.5, height: 1.4))),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Pill(severityLabel(alert.severity), color: color),
                        if (metric.isNotEmpty && alert.type != 'customer_churn')
                          Pill(metric, color: context.cs.primary, icon: Icons.analytics_rounded),
                        if (alert.createdAt != null)
                          Text(timeAgo(alert.createdAt), style: TextStyle(color: context.muted, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
