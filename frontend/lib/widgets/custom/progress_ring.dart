import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Custom-painted circular progress indicator (built with CustomPainter, not a library widget).
class ProgressRing extends StatelessWidget {
  final double value; // 0..1
  final double size;
  final double strokeWidth;
  final Color? color;
  final Widget? center;

  const ProgressRing({super.key, required this.value, this.size = 96, this.strokeWidth = 10, this.color, this.center});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value.isNaN ? 0 : value.clamp(0.0, 1.0),
          strokeWidth: strokeWidth,
          trackColor: scheme.surfaceContainerHighest,
          color: color ?? scheme.primary,
        ),
        child: Center(child: center),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value, strokeWidth;
  final Color trackColor, color;
  _RingPainter({required this.value, required this.strokeWidth, required this.trackColor, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(strokeWidth / 2, strokeWidth / 2) & Size(size.width - strokeWidth, size.height - strokeWidth);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, base..color = trackColor);
    if (value > 0) {
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * value, false, base..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.color != color || old.trackColor != trackColor || old.strokeWidth != strokeWidth;
}
