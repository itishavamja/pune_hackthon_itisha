import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/chips.dart';
import '../../widgets/sheet.dart';
import '../../widgets/states.dart';
import '../../widgets/success_check.dart';
import '../../widgets/toast.dart';
import 'campaign_card.dart';

void _refreshCampaigns(WidgetRef ref) {
  ref.invalidate(campaignsProvider);
  ref.invalidate(summaryProvider);
}

// ============================================================ edit
Future<void> showEditSheet(BuildContext context, WidgetRef ref, Campaign c) async {
  final saved = await showAppSheet<bool>(context, (_) => _EditSheet(campaign: c), full: true);
  if (saved == true && context.mounted) {
    _refreshCampaigns(ref);
    showToast(context, 'Message updated', kind: ToastKind.success);
  }
}

class _EditSheet extends ConsumerStatefulWidget {
  const _EditSheet({required this.campaign});
  final Campaign campaign;

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  late final _title = TextEditingController(text: widget.campaign.title ?? '');
  late final _message = TextEditingController(text: widget.campaign.message);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final message = _message.text.trim();
    if (message.isEmpty) {
      setState(() => _error = 'The message cannot be empty.');
      return;
    }
    final titleChanged = title.isNotEmpty && title != (widget.campaign.title ?? '');
    final messageChanged = message != widget.campaign.message;
    if (!titleChanged && !messageChanged) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).editCampaign(
            widget.campaign.id,
            title: titleChanged ? title : null,
            message: messageChanged ? message : null,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (e.isConflict) _refreshCampaigns(ref);
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Change the message', style: context.tt.titleLarge),
          const SizedBox(height: 4),
          Text('Change the words before you send. You can write in Hindi, Marathi or English.',
              style: TextStyle(color: context.muted, height: 1.4)),
          const SizedBox(height: 18),
          TextField(
            controller: _title,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Offer name', counterText: ''),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _message,
            maxLength: 1000,
            minLines: 5,
            maxLines: 9,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(labelText: 'Message to customers', alignLabelWithHint: true),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.error_rounded, color: Brand.danger, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: const TextStyle(color: Brand.danger))),
            ]),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : const Text('Save changes'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================ approve
Future<void> showApproveSheet(BuildContext context, WidgetRef ref, Campaign c) async {
  final result = await showAppSheet<ActionResult>(context, (_) => _ApproveSheet(campaign: c), full: true);
  _refreshCampaigns(ref); // refresh even on failure: status may have become "approved"
  if (result != null && context.mounted) {
    await showSuccessDialog(context, result);
  }
}

class _ApproveSheet extends ConsumerStatefulWidget {
  const _ApproveSheet({required this.campaign});
  final Campaign campaign;

  @override
  ConsumerState<_ApproveSheet> createState() => _ApproveSheetState();
}

class _ApproveSheetState extends ConsumerState<_ApproveSheet> {
  bool _sending = false;
  String? _error;

  Future<void> _approve() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final r = await ref.read(apiClientProvider).approve(widget.campaign.id);
      if (mounted) Navigator.of(context).pop(r);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.campaign;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Send this offer?', style: context.tt.titleLarge),
          const SizedBox(height: 4),
          Text(c.displayTitle, style: TextStyle(color: context.muted)),
          const SizedBox(height: 16),
          MessageBubble(text: c.message),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.people_alt_rounded, size: 18, color: context.cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${count(c.targetCount)} customers  •  ${audienceLabel(c.segment)}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Brand.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.science_rounded, color: Brand.info, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Demo Mode: no real WhatsApp or SMS is sent. This only simulates sending so you can see the full flow.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_rounded, color: Brand.danger, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(color: Brand.danger, height: 1.35))),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _sending ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _sending ? null : _approve,
                  icon: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(_sending ? 'Sending…' : (_error != null ? 'Try again' : 'Yes, send (demo)')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> showSuccessDialog(BuildContext context, ActionResult r) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => Dialog(
      backgroundColor: ctx.cardColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SuccessCheck(color: r.alreadyProcessed ? Brand.info : Brand.success),
            const SizedBox(height: 18),
            Text(r.alreadyProcessed ? 'Already sent' : 'Sent!', style: ctx.tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800))
                .animate()
                .fadeIn(delay: 700.ms, duration: 350.ms)
                .slideY(begin: 0.3, end: 0, delay: 700.ms),
            const SizedBox(height: 8),
            Text(r.message, textAlign: TextAlign.center, style: TextStyle(color: ctx.muted, height: 1.45, fontSize: 14.5))
                .animate()
                .fadeIn(delay: 850.ms, duration: 350.ms),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                if (r.demoMode) const Pill('Demo Mode', color: Brand.info, icon: Icons.science_rounded),
                Pill('${count(r.campaign.targetCount)} customers', color: Brand.success, icon: Icons.people_alt_rounded),
              ],
            ).animate().fadeIn(delay: 1000.ms, duration: 350.ms),
            const SizedBox(height: 22),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Done')),
          ],
        ),
      ),
    ).animate().scale(begin: const Offset(0.85, 0.85), duration: 350.ms, curve: Curves.easeOutBack),
  );
}

// ============================================================ reject
Future<void> confirmReject(BuildContext context, WidgetRef ref, Campaign c) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: const Icon(Icons.block_rounded, color: Brand.danger, size: 32),
      title: const Text("Don't send this offer?"),
      content: Text(
        '"${c.displayTitle}" will not be sent. You cannot undo this.',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Brand.danger, minimumSize: const Size(120, 44)),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text("Don't send"),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    await ref.read(apiClientProvider).reject(c.id);
    _refreshCampaigns(ref);
    if (context.mounted) showToast(context, 'Okay. This offer will not be sent.', kind: ToastKind.info);
  } on ApiException catch (e) {
    _refreshCampaigns(ref);
    if (context.mounted) showToast(context, e.message, kind: ToastKind.error);
  }
}

// ============================================================ detail + history
void showCampaignDetail(BuildContext context, Campaign c) {
  showAppSheet<void>(context, (_) => _DetailSheet(id: c.id, fallback: c), full: true);
}

class _DetailSheet extends ConsumerWidget {
  const _DetailSheet({required this.id, required this.fallback});
  final int id;
  final Campaign fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(campaignDetailProvider(id));
    final c = detail.valueOrNull ?? fallback;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: campaignIcon(c.type), color: campaignColor(c.type), size: 46),
              const SizedBox(width: 12),
              Expanded(child: Text(c.displayTitle, style: context.tt.titleLarge)),
              Pill(statusLabel(c.status), color: statusColor(c.status), icon: statusIcon(c.status)),
            ],
          ),
          const SizedBox(height: 18),
          _Row(icon: Icons.people_alt_rounded, label: 'For', value: '${count(c.targetCount)} • ${audienceLabel(c.segment)}'),
          if (c.objective != null) _Row(icon: Icons.flag_rounded, label: 'Goal', value: c.objective!),
          _Row(icon: Icons.translate_rounded, label: 'Language', value: c.language),
          const SizedBox(height: 14),
          Text('Message', style: TextStyle(color: context.muted, fontWeight: FontWeight.w700, fontSize: 12.5)),
          const SizedBox(height: 8),
          MessageBubble(text: c.message),
          if (c.reason != null) ...[
            const SizedBox(height: 16),
            Text('Why this offer?',
                style: TextStyle(color: context.muted, fontWeight: FontWeight.w700, fontSize: 12.5)),
            const SizedBox(height: 6),
            Text(c.reason!, style: const TextStyle(height: 1.5)),
          ],
          const SizedBox(height: 22),
          Text('History', style: context.tt.titleMedium),
          const SizedBox(height: 10),
          detail.when(
            loading: () => const Column(children: [Skeleton(height: 44), SizedBox(height: 8), Skeleton(height: 44)]),
            error: (e, _) => ErrorView(error: e, compact: true, onRetry: () => ref.invalidate(campaignDetailProvider(id))),
            data: (d) => Column(
              children: [
                for (var i = 0; i < d.history.length; i++)
                  _TimelineItem(entry: d.history[i], last: i == d.history.length - 1)
                      .animate()
                      .fadeIn(delay: (i * 80).ms, duration: 300.ms)
                      .slideX(begin: 0.06, end: 0, delay: (i * 80).ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: context.muted),
            const SizedBox(width: 10),
            SizedBox(width: 78, child: Text(label, style: TextStyle(color: context.muted))),
            Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
          ],
        ),
      );
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.entry, required this.last});
  final HistoryEntry entry;
  final bool last;

  (String, IconData, Color) get _meta => switch (entry.action) {
        'created' => ('Offer written', Icons.edit_note_rounded, Brand.amber),
        'edited' => ('You changed the message', Icons.edit_rounded, Brand.info),
        'approved' => ('You approved it', Icons.verified_rounded, Brand.info),
        'sent' => ('Sent (Demo Mode)', Icons.send_rounded, Brand.success),
        'send_failed' => ('Sending did not finish', Icons.error_rounded, Brand.danger),
        'rejected' => ('You chose not to send it', Icons.block_rounded, Brand.danger),
        _ => (entry.action, Icons.circle, Colors.grey),
      };

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = _meta;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                IconBadge(icon: icon, color: color, size: 30),
                if (!last) Expanded(child: Container(width: 2, color: context.hairline)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 14, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (entry.at != null)
                    Text(dayMonthTime(entry.at!), style: TextStyle(color: context.muted, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
