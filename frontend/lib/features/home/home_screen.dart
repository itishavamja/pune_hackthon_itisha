import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/analysis_actions.dart';
import '../../widgets/app_card.dart';
import '../../widgets/chips.dart';
import '../../widgets/count_up.dart';
import '../../widgets/info_sheet.dart';
import '../../widgets/sheet.dart';
import '../../widgets/states.dart';
import '../onboarding/onboarding_screen.dart';
import '../settings/api_settings_sheet.dart';
import 'forecast_chart.dart';

extension _Stagger on Widget {
  Widget stagger(int i) => animate()
      .fadeIn(delay: (70 * i).ms, duration: 420.ms)
      .slideY(begin: 0.10, end: 0, delay: (70 * i).ms, duration: 420.ms, curve: Curves.easeOutCubic);
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    invalidateAll(ref.invalidate);
    try {
      await ref.read(summaryProvider.future);
    } catch (_) {/* error state is shown by the UI */}
  }

  void _openSettings(BuildContext context) => showAppSheet(context, (_) => const ApiSettingsSheet());

  void _openHowItWorks(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (ctx) => OnboardingScreen(onDone: () => Navigator.of(ctx).pop()),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(summaryProvider);
    final forecast = ref.watch(forecastProvider);

    return RefreshIndicator(
      onRefresh: () => _refresh(ref),
      edgeOffset: 80,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _Header(
              summary: summary,
              onSettings: () => _openSettings(context),
              onHelp: () => _openHowItWorks(context),
            ),
          ),
          if (summary.hasError && !summary.hasValue)
            SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorView(
                error: summary.error!,
                onRetry: () => _refresh(ref),
                onSettings: () => _openSettings(context),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              sliver: SliverList.list(children: [
                if (summary.valueOrNull != null)
                  _AdviceCard(summary: summary.value!, forecast: forecast.valueOrNull).stagger(0),
                const AnalysisCta().stagger(1),
                const SizedBox(height: 20),
                Text('Your shop in numbers', style: context.tt.titleMedium).stagger(2),
                const SizedBox(height: 10),
                _KpiGrid(summary: summary.valueOrNull, forecast: forecast.valueOrNull).stagger(2),
                const SizedBox(height: 16),
                _ChartCard(forecast: forecast).stagger(3),
                const SizedBox(height: 14),
                if (summary.valueOrNull?.lastAnalysisAt != null)
                  Center(
                    child: Text(
                      'Last checked: ${dayMonthTime(summary.value!.lastAnalysisAt!)}',
                      style: TextStyle(color: context.muted, fontSize: 12),
                    ),
                  ).stagger(4),
              ]),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ header
class _Header extends StatelessWidget {
  const _Header({required this.summary, required this.onSettings, required this.onHelp});
  final AsyncValue<Summary> summary;
  final VoidCallback onSettings, onHelp;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 14, 12, 24),
      decoration: const BoxDecoration(
        gradient: Brand.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Text('360', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dukaan360',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                    Text('Predict before you lose', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'How this app works',
                onPressed: onHelp,
                icon: const Icon(Icons.help_outline_rounded, color: Colors.white),
              ),
              IconButton(
                tooltip: 'Connection settings',
                onPressed: onSettings,
                icon: const Icon(Icons.settings_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Text('Your sales in the last 7 days',
                style: TextStyle(color: Colors.white70, fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 4),
          summary.when(
            data: (s) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CountUp(
                  value: s.last7Revenue,
                  format: (v) => money(v),
                  style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1),
                ),
                const SizedBox(height: 8),
                _GrowthRow(summary: s),
              ],
            ),
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Skeleton(width: 190, height: 38), SizedBox(height: 12), Skeleton(width: 150, height: 22)],
              ),
            ),
            error: (_, __) => const Text('—', style: TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _GrowthRow extends StatelessWidget {
  const _GrowthRow({required this.summary});
  final Summary summary;

  @override
  Widget build(BuildContext context) {
    final g = summary.growthPct;
    if (g == null) {
      return const Text('Not enough days of sales to compare yet', style: TextStyle(color: Colors.white70));
    }
    final down = g < 0;
    final color = down ? const Color(0xFFFF8A8E) : const Color(0xFF6BE3A6);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 6,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(99)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(down ? Icons.trending_down_rounded : Icons.trending_up_rounded, size: 17, color: color),
              const SizedBox(width: 5),
              Text(signedPct(g), style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13.5)),
            ],
          ),
        ),
        if (summary.prev7Revenue != null)
          Text('last week: ${money(summary.prev7Revenue!)}', style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
      ],
    );
  }
}

// ------------------------------------------------------------------ plain-language advice
/// Says in plain sentences what is happening and what to do next. Built only from real numbers.
class _AdviceCard extends ConsumerWidget {
  const _AdviceCard({required this.summary, required this.forecast});
  final Summary summary;
  final Forecast? forecast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = summary.growthPct;
    final falling = (forecast?.isDeclining ?? false) || summary.salesStatus == 'declining';
    final stopped = summary.atRiskCustomers;
    final lines = <(IconData, Color, String)>[];

    if (falling && g != null && summary.prev7Revenue != null) {
      lines.add((
        Icons.trending_down_rounded,
        Brand.danger,
        'This week you sold ${money(summary.last7Revenue)}. That is ${g.abs().toStringAsFixed(0)}% less than last week (${money(summary.prev7Revenue!)}).'
      ));
    } else if (g != null && g >= 5) {
      lines.add((
        Icons.trending_up_rounded,
        Brand.success,
        'Good news: this week you sold ${money(summary.last7Revenue)}, which is ${g.toStringAsFixed(0)}% more than last week.'
      ));
    } else {
      lines.add((Icons.trending_flat_rounded, Brand.info, 'Your sales are steady: ${money(summary.last7Revenue)} in the last 7 days.'));
    }
    if (stopped > 0) {
      lines.add((
        Icons.person_off_rounded,
        Brand.amber,
        '$stopped regular customers have not come for 2 weeks or more.'
      ));
    }
    final proj = forecast?.projectedChangePct;
    if (proj != null && proj < -15) {
      lines.add((
        Icons.insights_rounded,
        Brand.danger,
        'Next week may be ${proj.abs().toStringAsFixed(0)}% lower than a normal week.'
      ));
    }

    final needsAction = falling || stopped > 0;
    final tint = needsAction ? Brand.danger : Brand.success;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        color: tint.withValues(alpha: context.dark ? 0.14 : 0.07),
        borderColor: tint.withValues(alpha: 0.3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(needsAction ? Icons.flag_rounded : Icons.check_circle_rounded, color: tint, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(needsAction ? 'What needs your attention' : 'Your shop looks healthy',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final (icon, color, text) in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(text, style: const TextStyle(fontSize: 14.5, height: 1.45))),
                  ],
                ),
              ),
            if (needsAction) ...[
              const SizedBox(height: 2),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () => ref.read(navIndexProvider.notifier).state = 3,
                icon: const Icon(Icons.local_offer_rounded, size: 18),
                label: const Text('See offers to win them back'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ KPI grid
class _KpiGrid extends ConsumerWidget {
  const _KpiGrid({required this.summary, required this.forecast});
  final Summary? summary;
  final Forecast? forecast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void go(int i) => ref.read(navIndexProvider.notifier).state = i;
    final s = summary;
    final f = forecast;
    final proj = f?.projectedChangePct;
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // Fixed tile height (not an aspect ratio) so content never overflows on narrow phones.
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 142,
      ),
      children: [
        _Kpi(
          icon: Icons.today_rounded,
          color: Brand.info,
          label: "Today's sales",
          value: s?.todayRevenue,
          format: money,
          foot: 'so far today',
        ),
        _Kpi(
          icon: Icons.account_balance_wallet_rounded,
          color: Brand.success,
          label: 'All sales so far',
          value: s?.totalRevenue,
          format: money,
          foot: 'since you started',
        ),
        _Kpi(
          icon: Icons.people_alt_rounded,
          color: const Color(0xFF8B5CF6),
          label: 'Total customers',
          value: s?.totalCustomers.toDouble(),
          format: (v) => count(v.round()),
          foot: 'who paid you',
        ),
        _Kpi(
          icon: Icons.person_off_rounded,
          color: Brand.danger,
          label: 'Stopped coming',
          value: s?.atRiskCustomers.toDouble(),
          format: (v) => count(v.round()),
          foot: 'customers to win back',
          onTap: () => go(1),
        ),
        _Kpi(
          icon: Icons.notifications_active_rounded,
          color: Brand.amber,
          label: 'Warnings',
          value: s?.alertsCount.toDouble(),
          format: (v) => count(v.round()),
          foot: 'tap to read',
          onTap: () => go(2),
        ),
        _Kpi(
          icon: Icons.insights_rounded,
          color: context.cs.primary,
          label: 'Expected next 7 days',
          value: f?.predictedRevenue,
          format: money,
          foot: proj == null ? 'our estimate' : '${proj.abs().toStringAsFixed(0)}% ${proj < 0 ? 'less' : 'more'} than normal',
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.format,
    required this.foot,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label, foot;
  final double? value;
  final String Function(double) format;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: icon, color: color, size: 34),
              const Spacer(),
              if (onTap != null) Icon(Icons.chevron_right_rounded, color: context.muted, size: 20),
            ],
          ),
          const Spacer(),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          if (value == null)
            const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Skeleton(width: 90, height: 20))
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: CountUp(value: value!, format: format, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            ),
          Text(foot, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.muted, fontSize: 11)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ chart card
class _ChartCard extends ConsumerWidget {
  const _ChartCard({required this.forecast});
  final AsyncValue<Forecast> forecast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(forecastRangeProvider);
    const ranges = [(14, '2 weeks'), (30, '1 month'), (60, '2 months')];
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Your sales: past and next 7 days', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              ),
              const InfoButton(
                title: 'How is the "expected" part made?',
                points: [
                  (Icons.history_rounded, 'We look at your past sales, including busy weekends and quiet days.'),
                  (Icons.auto_graph_rounded, 'From that pattern we estimate the next 7 days (the dotted line).'),
                  (Icons.info_outline_rounded, 'It is an estimate to help you plan. It is not a promise.'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final (days, label) in ranges)
                FilterPill(
                  label: label,
                  selected: range == days,
                  onTap: () => ref.read(forecastRangeProvider.notifier).state = days,
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              _LegendDot(color: Brand.primary, label: 'Past sales'),
              SizedBox(width: 14),
              _LegendDot(color: Brand.amber, label: 'Expected'),
            ],
          ),
          const SizedBox(height: 10),
          forecast.when(
            data: (f) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ForecastChart(data: f).animate().fadeIn(duration: 500.ms),
                const SizedBox(height: 12),
                _ForecastNote(forecast: f),
              ],
            ),
            loading: () => const Skeleton(height: 220, radius: 16),
            error: (e, _) => ErrorView(
              error: e,
              compact: true,
              onRetry: () => ref.invalidate(forecastProvider),
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastNote extends StatelessWidget {
  const _ForecastNote({required this.forecast});
  final Forecast forecast;

  @override
  Widget build(BuildContext context) {
    final f = forecast;
    final change = f.projectedChangePct;
    final down = (change ?? 0) < 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (down ? Brand.danger : Brand.success).withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(down ? Icons.south_east_rounded : Icons.north_east_rounded,
              color: down ? Brand.danger : Brand.success, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'We expect about '),
                  TextSpan(text: money(f.predictedRevenue), style: const TextStyle(fontWeight: FontWeight.w800)),
                  const TextSpan(text: ' in the next 7 days.'),
                  if (change != null && f.baselineRevenue != null)
                    TextSpan(
                      text: ' That is ${change.abs().toStringAsFixed(0)}% ${down ? 'less' : 'more'} than a normal week (${money(f.baselineRevenue!)}).',
                    ),
                ],
              ),
              style: const TextStyle(fontSize: 13.5, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: context.muted, fontWeight: FontWeight.w600)),
        ],
      );
}
