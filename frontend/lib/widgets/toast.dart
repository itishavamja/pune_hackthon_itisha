import 'package:flutter/material.dart';

import '../core/theme.dart';

enum ToastKind { info, success, error }

/// Floating message above the bottom navigation bar.
void showToast(BuildContext context, String message, {ToastKind kind = ToastKind.info}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final (icon, color) = switch (kind) {
    ToastKind.success => (Icons.check_circle_rounded, const Color(0xFF47D18C)),
    ToastKind.error => (Icons.error_rounded, const Color(0xFFFF7A7F)),
    ToastKind.info => (Icons.info_rounded, const Color(0xFF7DB4FF)),
  };
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        duration: Duration(seconds: kind == ToastKind.error ? 5 : 3),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 92),
        backgroundColor: Brand.navy,
        content: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}
