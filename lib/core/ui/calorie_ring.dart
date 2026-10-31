/// The hero calorie ring: a circular progress with an animated sweep and a
/// free centre slot (剩余 kcal 大数字).
library;

import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

/// The ring. [progress] is `intake / budget` clamped to `0..1` for drawing;
/// the centre [child] is laid out in a fixed [size] box.
class CalorieRing extends StatelessWidget {
  /// Creates the ring.
  const CalorieRing({
    required this.progress,
    required this.child,
    super.key,
    this.size = 176,
    this.strokeWidth = AppDim.ringStroke,
    this.color,
    this.trackColor,
  });

  /// Fraction complete, `0..1`.
  final double progress;

  /// The centre content (usually a column with the remaining kcal).
  final Widget child;

  /// Outer diameter.
  final double size;

  /// Ring stroke thickness.
  final double strokeWidth;

  /// Fill colour; defaults to `colorScheme.primary`.
  final Color? color;

  /// Track colour; defaults to `colorScheme.surfaceContainerHighest`.
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double clamped = progress.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: clamped),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double t, Widget? _) => CustomPaint(
        size: Size.square(size),
        painter: _RingPainter(
          progress: t,
          strokeWidth: strokeWidth,
          color: color ?? colors.primary,
          trackColor: trackColor ?? colors.surfaceContainerHighest,
        ),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = (size.shortestSide - strokeWidth) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    final Paint fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    final double sweep = 2 * 3.141592653589793 * progress;
    if (sweep > 0) {
      canvas.drawArc(rect, -3.141592653589793 / 2, sweep, false, fill);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
