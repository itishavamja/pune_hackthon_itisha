import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Three bouncing dots ("AI is typing...").
class TypingDots extends StatelessWidget {
  const TypingDots({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          )
              .animate(onPlay: (ctl) => ctl.repeat(reverse: true), delay: (i * 160).ms)
              .moveY(begin: 2, end: -4, duration: 420.ms, curve: Curves.easeInOut)
              .fade(begin: 0.35, end: 1, duration: 420.ms),
      ],
    );
  }
}
