import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/chips.dart';
import '../../widgets/info_sheet.dart';
import '../../widgets/sheet.dart';
import '../../widgets/states.dart';
import '../settings/api_settings_sheet.dart';

Color segmentColor(String name) => switch (name) {
      'Active' => Brand.primary,
      'Early Warning' => Brand.amber,
      'At Risk' => Brand.danger,
      _ => Brand.info,
    };

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 320) {
        ref.read(churnProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(churnProvider);
    final filter = ref.watch(churnFilterProvider);
    final top = MediaQuery.paddingOf(context).top;

    Widget body;
    if (s.error != null && s.summary == null) {
      body = SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorView(
          error: s.error!,
          onRetry: () => ref.invalidate(churnProvider),
          onSettings: () => showAppSheet(context, (_) => const ApiSettingsSheet()),
        ),
      );
    } else if (s.summary == null) {
      body = const SliverPadding(
        padding: EdgeInsets.all(16),
        sliver: SliverToBoxAdapter(
          child: Column(children: [SkeletonCard(height: 150), SizedBox(height: 12), SkeletonCard(height: 90), SizedBox(height: 12), SkeletonCard(height: 80)]),
        ),
      );
    } else {
      body = SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        sliver: SliverList.list(children: [
          _SummaryCard(summary: s.summary!).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0),
          const SizedBox(height: 12),
          _SegmentBar(segments: s.segments)
              .animate()
              .fadeIn(delay: 100.ms, duration: 400.ms)
              .slideY(begin: 0.08, end: 0, delay: 100.ms),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text('Customers who stopped coming', style: context.tt.titleMedium),
              ),
              Text('${s.total} customers', style: TextStyle(color: context.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterPill(
                  label: 'All',
                  selected: filter == null,
                  onTap: () => ref.read(churnFilterProvider.notifier).state = null,
                ),
                const SizedBox(width: 8),
                FilterPill(
                  label: 'Most urgent',
                  selected: filter == 'HIGH',
                  onTap: () => ref.read(churnFilterProvider.notifier).state = 'HIGH',
                ),
                const SizedBox(width: 8),
                FilterPill(
                  label: 'Slowing down',
                  selected: filter == 'MEDIUM',
                  onTap: () => ref.read(churnFilterProvider.notifier).state = 'MEDIUM',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (s.loading)
            const Column(children: [SkeletonCard(height: 78), SizedBox(height: 10), SkeletonCard(height: 78)])
          else if (s.items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: EmptyState(
                icon: Icons.celebration_rounded,
                color: Brand.success,
                title: 'No customers here',
                subtitle: 'Nobody is in this group right now. That is good news.',
              ),
            )
          else ...[
            for (var i = 0; i < s.items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CustomerTile(c: s.items[i])
                    .animate()
                    .fadeIn(delay: ((i % 10) * 45).ms, duration: 350.ms)
                    .slideX(begin: 0.08, end: 0, delay: ((i % 10) * 45).ms, duration: 350.ms),
              ),
            if (s.loadingMore)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.6))),
              )
            else if (!s.hasMore)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Center(child: Text('That is everyone on the list', style: TextStyle(color: context.muted, fontSize: 12))),
              ),
          ],
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(churnProvider.notifier).refresh(),
      edgeOffset: top + 40,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, top + 18, 20, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My Customers', style: context.tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text('Who is still coming, and who has stopped',
                            style: TextStyle(color: context.muted, fontSize: 13.5)),
                      ],
                    ),
                  ),
                  const InfoButton(
                    title: 'What does "stopped coming" mean?',
                    points: [
                      (Icons.repeat_rounded, 'Every regular customer has their own rhythm, for example every 4 days.'),
                      (Icons.hourglass_bottom_rounded, 'If a customer stays away much longer than their rhythm, and it has been 2 weeks or more, we say they stopped coming.'),
                      (Icons.person_add_alt_1_rounded, 'New customers are never put in this list, because we do not know their rhythm yet.'),
                      (Icons.local_offer_rounded, 'Tap a customer to see details. Then use the Offers tab to bring them back.'),
                    ],
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

// ------------------------------------------------------------------ summary
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final ChurnSummary summary;

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, String value, Color color) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 9),
              Expanded(child: Text(label, style: TextStyle(color: context.muted, fontSize: 12.5))),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ],
          ),
        );

    return AppCard(
      child: Row(
        children: [
          _RiskRing(percent: summary.churnRiskPct, label: 'stopped'),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              children: [
                stat('Stopped coming', '${summary.atRiskCustomers}', Brand.danger),
                stat('Coming less often', '${summary.earlyWarningCustomers}', Brand.amber),
                stat('Average bill', money(summary.averageBasket), Brand.info),
                stat('Their past spending', money(summary.atRiskSpending), Brand.success),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated gauge: teal when healthy, amber when watch-worthy, red when high.
class _RiskRing extends StatelessWidget {
  const _RiskRing({required this.percent, required this.label});
  final double percent;
  final String label;

  @override
  Widget build(BuildContext context) {
    final target = (percent / 100).clamp(0.0, 1.0);
    final color = percent >= 35 ? Brand.danger : (percent >= 15 ? Brand.amber : Brand.success);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: target),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => SizedBox(
        width: 112,
        height: 112,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 112,
              height: 112,
              child: CircularProgressIndicator(
                value: v,
                strokeWidth: 11,
                strokeCap: StrokeCap.round,
                backgroundColor: context.hairline,
                color: color,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${(v * 100).round()}%', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
                Text(label, style: TextStyle(fontSize: 11, color: context.muted, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ segments
class _SegmentBar extends StatelessWidget {
  const _SegmentBar({required this.segments});
  final List<Segment> segments;

  @override
  Widget build(BuildContext context) {
    final visible = segments.where((s) => s.count > 0).toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your customers at a glance', style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 14,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1,
                  child: FractionallySizedBox(
                    widthFactor: v,
                    child: Row(
                      children: [
                        for (final s in visible)
                          Expanded(
                            flex: s.count,
                            child: Container(
                              margin: const EdgeInsets.only(right: 2),
                              color: segmentColor(s.name),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              for (final s in segments)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 9, height: 9, decoration: BoxDecoration(color: segmentColor(s.name), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('${segmentLabel(s.name)} ', style: TextStyle(color: context.muted, fontSize: 12.5)),
                    Text('${s.count}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ tile
class _CustomerTile extends StatefulWidget {
  const _CustomerTile({required this.c});
  final AtRiskCustomer c;

  @override
  State<_CustomerTile> createState() => _CustomerTileState();
}

class _CustomerTileState extends State<_CustomerTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final color = severityColor(c.riskLevel);
    final days = c.daysInactive;
    final gap = c.normalIntervalDays;
    final times = (days != null && gap != null && gap > 0) ? days / gap : null;

    return AppCard(
      onTap: () => setState(() => _open = !_open),
      padding: const EdgeInsets.all(14),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Text(initials(c.name), style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 3),
                      Text(
                        'Last came ${dayMonthFromIso(c.lastVisit)}  •  ${days ?? '—'} days ago',
                        style: TextStyle(color: context.muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Pill(riskLabel(c.riskLevel), color: color),
                    const SizedBox(height: 5),
                    Text(money(c.totalSpending), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  ],
                ),
              ],
            ),
            if (_open) ...[
              const SizedBox(height: 12),
              Divider(color: context.hairline, height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Mini(label: 'Times came', value: '${c.visitCount}'),
                  _Mini(label: 'Usually comes', value: gap == null ? '—' : 'every ${gap.toStringAsFixed(0)} days'),
                  _Mini(label: 'Total spent', value: money(c.totalSpending)),
                ],
              ),
              if (times != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_rounded, size: 18, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'They usually come every ${gap!.toStringAsFixed(0)} days, but it has been $days days. Send them an offer from the Offers tab.',
                          style: const TextStyle(fontSize: 12.5, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: context.muted, fontSize: 11.5)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ],
        ),
      );
}
