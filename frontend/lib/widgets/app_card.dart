import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Rounded surface used everywhere. Tappable when [onTap] is given.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.gradient,
    this.borderColor,
    this.margin,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? context.cardColor) : null,
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(color: borderColor ?? context.hairline),
        boxShadow: context.dark
            ? null
            : const [BoxShadow(color: Color(0x0F0B1F3A), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Small coloured circle holding an icon.
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, required this.color, this.size = 40});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: size * 0.52),
      );
}
