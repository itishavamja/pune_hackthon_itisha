import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Small coloured label (status, risk level, AI source...).
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, required this.color, this.icon, this.filled = false});
  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: filled ? Colors.white : color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: filled ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }
}

Color severityColor(String s) => switch (s.toUpperCase()) {
      'HIGH' => Brand.danger,
      'MEDIUM' => Brand.amber,
      _ => Brand.info,
    };

Color statusColor(String s) => switch (s) {
      'draft' => Brand.amber,
      'approved' => Brand.info,
      'sent' => Brand.success,
      'rejected' => Brand.danger,
      _ => Colors.grey,
    };

IconData statusIcon(String s) => switch (s) {
      'draft' => Icons.edit_note_rounded,
      'approved' => Icons.verified_rounded,
      'sent' => Icons.send_rounded,
      'rejected' => Icons.block_rounded,
      _ => Icons.circle,
    };

String statusLabel(String s) => switch (s) {
      'draft' => 'Waiting for you',
      'approved' => 'Approved',
      'sent' => 'Sent (demo)',
      'rejected' => 'Not sent',
      _ => s,
    };

/// Selectable filter chip with a smooth colour change.
class FilterPill extends StatelessWidget {
  const FilterPill({super.key, required this.label, required this.selected, required this.onTap, this.count});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final primary = context.cs.primary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? primary : context.cardColor,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: selected ? primary : context.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: selected ? (context.dark ? Brand.navy : Colors.white) : context.cs.onSurface,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: selected
                        ? (context.dark ? Brand.navy : Colors.white).withValues(alpha: 0.8)
                        : context.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
