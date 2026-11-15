import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'app_card.dart';
import 'sheet.dart';

/// A short "what does this mean?" explanation in simple words.
Future<void> showInfoSheet(
  BuildContext context, {
  required String title,
  required List<(IconData, String)> points,
  String? footnote,
}) {
  return showAppSheet<void>(
    context,
    (ctx) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: ctx.tt.titleLarge),
          const SizedBox(height: 16),
          for (final (icon, text) in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBadge(icon: icon, color: ctx.cs.primary, size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(text, style: const TextStyle(fontSize: 15, height: 1.5)),
                    ),
                  ),
                ],
              ),
            ),
          if (footnote != null)
            Text(footnote, style: TextStyle(color: ctx.muted, fontSize: 13, height: 1.45)),
          const SizedBox(height: 14),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Got it')),
        ],
      ),
    ),
  );
}

/// Small "?" button that opens [showInfoSheet].
class InfoButton extends StatelessWidget {
  const InfoButton({super.key, required this.title, required this.points, this.footnote});
  final String title;
  final List<(IconData, String)> points;
  final String? footnote;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'What does this mean?',
        visualDensity: VisualDensity.compact,
        onPressed: () => showInfoSheet(context, title: title, points: points, footnote: footnote),
        icon: Icon(Icons.help_outline_rounded, color: context.muted),
      );
}
