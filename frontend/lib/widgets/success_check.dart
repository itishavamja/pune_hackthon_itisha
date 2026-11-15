import 'package:flutter/material.dart';

/// Circle that draws itself, then a tick that draws itself - used for "sent" confirmation.
class SuccessCheck extends StatefulWidget {
  const SuccessCheck({super.key, this.size = 110, this.color = const Color(0xFF2FA36B)});
  final double size;
  final Color color;

  @override
  State<SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<SuccessCheck> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(painter: _CheckPainter(_c.value, widget.color)),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 6;

    // soft filled disc fades in
    final discT = Curves.easeOut.transform((t / 0.6).clamp(0, 1));
    canvas.drawCircle(center, radius, Paint()..color = color.withValues(alpha: 0.14 * discT));

    // ring draws itself (0 -> 0.6)
    final ringT = Curves.easeInOut.transform((t / 0.6).clamp(0, 1));
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -1.5708, 6.2832 * ringT, false, ring);

    // tick draws itself (0.55 -> 1)
    final tickT = Curves.easeOut.transform(((t - 0.55) / 0.45).clamp(0, 1));
    if (tickT > 0) {
      final p = Path()
        ..moveTo(size.width * 0.29, size.height * 0.52)
        ..lineTo(size.width * 0.44, size.height * 0.66)
        ..lineTo(size.width * 0.72, size.height * 0.36);
      final metric = p.computeMetrics().first;
      canvas.drawPath(metric.extractPath(0, metric.length * tickT), ring..strokeWidth = 7);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t || old.color != color;
}
