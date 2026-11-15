import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/format.dart';
import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/app_card.dart';
import '../../widgets/chips.dart';

IconData campaignIcon(String type) => switch (type) {
      'win_back' => Icons.favorite_rounded,
      'weekend_promotion' => Icons.celebration_rounded,
      'basket_size' => Icons.shopping_basket_rounded,
      _ => Icons.campaign_rounded,
    };

Color campaignColor(String type) => switch (type) {
      'win_back' => Brand.danger,
      'weekend_promotion' => Brand.amber,
      'basket_size' => Brand.info,
      _ => Brand.primary,
    };

/// A chat-style bubble so the merchant sees the message the way customers will.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final bg = context.dark ? const Color(0xFF1C3B30) : const Color(0xFFDDF6D2);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
      ),
      child: Text(text, style: const TextStyle(fontSize: 14.5, height: 1.55)),
    );
  }
}

class CampaignCard extends StatefulWidget {
  const CampaignCard({
    super.key,
    required this.campaign,
    required this.onOpen,
    required this.onEdit,
    required this.onApprove,
    required this.onReject,
  });

  final Campaign campaign;
  final VoidCallback onOpen, onEdit, onApprove, onReject;

  @override
  State<CampaignCard> createState() => _CampaignCardState();
}

class _CampaignCardState extends State<CampaignCard> {
  bool _showWhy = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.campaign;
    final accent = campaignColor(c.type);
    return AppCard(
      onTap: widget.onOpen,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(icon: campaignIcon(c.type), color: accent, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.displayTitle,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, height: 1.25)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.people_alt_rounded, size: 15, color: context.muted),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text('${audienceLabel(c.segment)} (${count(c.targetCount)})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: context.muted, fontSize: 12.5)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Pill(statusLabel(c.status), color: statusColor(c.status), icon: statusIcon(c.status)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text('Message your customers will get',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.muted, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Pill(c.language, color: context.cs.primary),
            ],
          ),
          const SizedBox(height: 8),
          MessageBubble(text: c.message),
          if (c.reason != null && c.reason!.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _showWhy = !_showWhy),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, size: 18, color: context.cs.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text('Why this offer?',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.cs.primary, fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                  const SizedBox(width: 2),
                  AnimatedRotation(
                    turns: _showWhy ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: context.cs.primary, size: 20),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _showWhy
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(c.reason!, style: TextStyle(color: context.muted, fontSize: 13, height: 1.45)),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
          const SizedBox(height: 14),
          _Footer(c: c, onEdit: widget.onEdit, onApprove: widget.onApprove, onReject: widget.onReject),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.c, required this.onEdit, required this.onApprove, required this.onReject});
  final Campaign c;
  final VoidCallback onEdit, onApprove, onReject;

  @override
  Widget build(BuildContext context) {
    if (c.isDraft) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Change'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Brand.danger,
                    side: BorderSide(color: Brand.danger.withValues(alpha: 0.4)),
                  ),
                  onPressed: onReject,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text("Don't send"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: onApprove,
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Send this offer'),
          ),
        ],
      );
    }
    if (c.isSent) {
      return _Banner(
        color: Brand.success,
        icon: Icons.check_circle_rounded,
        text: 'Sent in Demo Mode${c.sentAt == null ? '' : ' • ${dayMonthTime(c.sentAt!)}'}',
      );
    }
    if (c.isRejected) {
      return const _Banner(color: Colors.grey, icon: Icons.block_rounded, text: 'You chose not to send this offer.');
    }
    // approved but not sent (delivery failed): allow retry
    return Column(
      children: [
        const _Banner(color: Brand.amber, icon: Icons.warning_amber_rounded, text: 'Sending did not finish. Please try again.'),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: onApprove,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Try sending again'),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.icon, required this.text});
  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 9),
            Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13))),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms);
}
