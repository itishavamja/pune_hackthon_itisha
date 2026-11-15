import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/analysis_actions.dart';
import '../../widgets/app_card.dart';
import '../../widgets/chips.dart';
import '../../widgets/sheet.dart';
import '../../widgets/states.dart';
import '../settings/api_settings_sheet.dart';
import 'campaign_card.dart';
import 'campaign_sheets.dart';

class GrowthScreen extends ConsumerStatefulWidget {
  const GrowthScreen({super.key});

  @override
  ConsumerState<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends ConsumerState<GrowthScreen> {
  String? _status; // null = all

  @override
  Widget build(BuildContext context) {
    final campaigns = ref.watch(campaignsProvider);
    final analysis = ref.watch(analysisProvider);
    final list = campaigns.valueOrNull?.campaigns ?? const <Campaign>[];
    final top = MediaQuery.paddingOf(context).top;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(campaignsProvider);
        try {
          await ref.read(campaignsProvider.future);
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
                  Text('Offers to win customers back', style: context.tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('The AI writes the message. You read it, change it if you like, and press Send. Nothing goes out without you.',
                      style: TextStyle(color: context.muted, fontSize: 13.5, height: 1.4)),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.list(children: [
              _StepsCard(
                checked: analysis.result != null,
                hasOffers: list.any((c) => c.isDraft),
                anySent: list.any((c) => c.isSent),
              ).animate().fadeIn(duration: 350.ms),
              const SizedBox(height: 14),
              const _LanguageRow().animate().fadeIn(duration: 350.ms),
              const SizedBox(height: 12),
              const _InsightCard()
                  .animate()
                  .fadeIn(delay: 80.ms, duration: 400.ms)
                  .slideY(begin: 0.08, end: 0, delay: 80.ms),
              const SizedBox(height: 18),
            ]),
          ),
          ..._campaignSlivers(context, campaigns),
        ],
      ),
    );
  }

  List<Widget> _campaignSlivers(BuildContext context, AsyncValue<CampaignsPage> campaigns) {
    return campaigns.when(
      loading: () => [
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 120),
          sliver: SliverToBoxAdapter(
            child: Column(children: [SkeletonCard(height: 260), SizedBox(height: 12), SkeletonCard(height: 260)]),
          ),
        ),
      ],
      error: (e, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorView(
            error: e,
            onRetry: () => ref.invalidate(campaignsProvider),
            onSettings: () => showAppSheet(context, (_) => const ApiSettingsSheet()),
          ),
        ),
      ],
      data: (page) {
        final all = page.campaigns;
        if (all.isEmpty) {
          return [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.auto_awesome_rounded,
                title: 'No offers yet',
                subtitle: 'Tap "Check my shop" and Dukaan360 will write offers to bring customers back and grow your sales.',
                action: const SizedBox(width: 230, child: RunAnalysisButton()),
              ),
            ),
          ];
        }
        int n(String s) => all.where((c) => c.status == s).length;
        final shown = _status == null ? all : all.where((c) => c.status == _status).toList();
        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverList.list(children: [
              Row(
                children: [
                  Expanded(child: Text('Offers ready for you', style: context.tt.titleMedium)),
                  Text('${all.length} offers', style: TextStyle(color: context.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterPill(label: 'All', count: all.length, selected: _status == null, onTap: () => setState(() => _status = null)),
                    const SizedBox(width: 8),
                    FilterPill(label: 'To review', count: n('draft'), selected: _status == 'draft', onTap: () => setState(() => _status = 'draft')),
                    const SizedBox(width: 8),
                    FilterPill(label: 'Sent', count: n('sent'), selected: _status == 'sent', onTap: () => setState(() => _status = 'sent')),
                    const SizedBox(width: 8),
                    FilterPill(label: 'Not sent', count: n('rejected'), selected: _status == 'rejected', onTap: () => setState(() => _status = 'rejected')),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: EmptyState(
                    icon: Icons.inbox_rounded,
                    color: Brand.info,
                    title: 'Nothing here',
                    subtitle: 'No offers in this group.',
                  ),
                )
              else
                for (var i = 0; i < shown.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: CampaignCard(
                      key: ValueKey('campaign-${shown[i].id}'),
                      campaign: shown[i],
                      onOpen: () => showCampaignDetail(context, shown[i]),
                      onEdit: () => showEditSheet(context, ref, shown[i]),
                      onApprove: () => showApproveSheet(context, ref, shown[i]),
                      onReject: () => confirmReject(context, ref, shown[i]),
                    )
                        .animate()
                        .fadeIn(delay: (i * 90).ms, duration: 420.ms)
                        .slideY(begin: 0.1, end: 0, delay: (i * 90).ms, duration: 420.ms, curve: Curves.easeOutCubic),
                  ),
            ]),
          ),
        ];
      },
    );
  }
}

// ------------------------------------------------------------------ language
class _LanguageRow extends ConsumerWidget {
  const _LanguageRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Language of the offer message',
            style: TextStyle(color: context.muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final l in const ['Hindi', 'Marathi', 'English'])
              FilterPill(
                label: l,
                selected: lang == l,
                onTap: () {
                  ref.read(languageProvider.notifier).state = l;
                  ref.read(sharedPrefsProvider).setString(kPrefLanguage, l);
                },
              ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ AI insight
class _InsightCard extends ConsumerWidget {
  const _InsightCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analysisProvider);
    final r = state.result;

    if (state.running) {
      return const AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 160, height: 16),
            SizedBox(height: 14),
            Skeleton(height: 13),
            SizedBox(height: 8),
            Skeleton(height: 13),
            SizedBox(height: 8),
            Skeleton(width: 220, height: 13),
          ],
        ),
      );
    }

    if (r == null) {
      return AppCard(
        gradient: LinearGradient(colors: [
          context.cs.primary.withValues(alpha: 0.14),
          context.cs.primary.withValues(alpha: 0.04),
        ]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              IconBadge(icon: Icons.auto_awesome_rounded, color: context.cs.primary),
              const SizedBox(width: 12),
              Expanded(child: Text('Find out what is going wrong', style: context.tt.titleMedium)),
            ]),
            const SizedBox(height: 10),
            Text(
              'Dukaan360 looks at your sales, customers and payments, explains what is happening in simple words, and writes offers for you.',
              style: TextStyle(color: context.muted, height: 1.45),
            ),
            const SizedBox(height: 14),
            const RunAnalysisButton(),
          ],
        ),
      );
    }

    final extraWarnings = r.warnings.where((w) => !w.startsWith('AI service unavailable')).toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: Icons.psychology_rounded, color: context.cs.primary),
              const SizedBox(width: 12),
              Expanded(child: Text('What is happening in your shop', style: context.tt.titleMedium)),
              r.usedAi
                  ? const Pill('AI-written', color: Brand.primary, icon: Icons.auto_awesome_rounded)
                  : const Pill('Standard text', color: Brand.amber, icon: Icons.description_rounded),
            ],
          ),
          const SizedBox(height: 12),
          Text(r.explanationText ?? 'No explanation available.', style: const TextStyle(fontSize: 15, height: 1.55)),
          if (!r.usedAi) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: context.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'This is standard wording (the AI was not used this time). The numbers always come from your own sales.',
                    style: TextStyle(color: context.muted, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ],
          for (final w in extraWarnings) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: Brand.amber),
                const SizedBox(width: 6),
                Expanded(child: Text(w, style: const TextStyle(fontSize: 12, height: 1.4))),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Divider(color: context.hairline, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Checked ${r.generatedAt == null ? '' : timeAgo(r.generatedAt)}${r.language == null ? '' : '  •  ${r.language}'}',
                  style: TextStyle(color: context.muted, fontSize: 12),
                ),
              ),
              const SizedBox(width: 140, child: _SmallRun()),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallRun extends ConsumerWidget {
  const _SmallRun();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      onPressed: () => runAnalysis(context, ref, goToGrowth: false),
      icon: const Icon(Icons.refresh_rounded, size: 18),
      label: const Text('Check again'),
    );
  }
}

// ------------------------------------------------------------------ 3-step guide
/// Shows the whole journey in three simple steps and where the shopkeeper is now.
class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.checked, required this.hasOffers, required this.anySent});
  final bool checked, hasOffers, anySent;

  @override
  Widget build(BuildContext context) {
    final steps = <(String, String, bool)>[
      ('1', 'Check my shop', checked),
      ('2', 'Read the offer', checked && (hasOffers || anySent)),
      ('3', 'Send it', anySent),
    ];
    // the first unfinished step is the one to do next
    final current = steps.indexWhere((s) => !s.$3);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How it works', style: TextStyle(color: context.muted, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: steps[i].$3
                              ? Brand.success
                              : (i == current ? context.cs.primary : context.hairline),
                        ),
                        child: steps[i].$3
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                            : Text(steps[i].$1,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: i == current ? (context.dark ? Brand.navy : Colors.white) : context.muted,
                                )),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        steps[i].$2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.25,
                          fontWeight: i == current ? FontWeight.w800 : FontWeight.w600,
                          color: i == current ? context.cs.onSurface : context.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < steps.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 26),
                    child: Icon(Icons.chevron_right_rounded, color: context.muted, size: 20),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
