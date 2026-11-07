/// The hero calorie ring: a circular progress with an animated sweep and a
/// free centre slot (剩余 kcal 大数字).
library;

import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

/// The ring. [progress] is `intake / budget` clamped to `0..1` for drawing;
/// the centre [child] is laid out in a fixed [size] box.
///
/// With [gradientEndColor] the sweep runs as a gradient from [color] into
/// that accent (the gradient spans exactly the drawn arc, so the tip always
/// lands on the accent regardless of progress) and the arc gets a soft outer
/// glow. Without it the ring stays the flat solid stroke.
class CalorieRing extends StatelessWidget {
  /// Creates the ring.
  const CalorieRing({
    required this.progress,
    required this.child,
    super.key,
    this.size = 176,
    this.strokeWidth = AppDim.ringStroke,
    this.color,
    this.gradientEndColor,
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

  /// Gradient tip colour; `null` renders the flat solid stroke.
  final Color? gradientEndColor;

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
          gradientEndColor: gradientEndColor,
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
    required this.gradientEndColor,
    required this.trackColor,
  });

  final double progress;
  final double strokeWidth;
  final Color color;
  final Color? gradientEndColor;
  final Color trackColor;

  /// The arc's start angle: 12 o'clock, sweeping clockwise.
  static const double _startAngle = -3.141592653589793 / 2;

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

    final double sweep = 2 * 3.141592653589793 * progress;
    if (sweep <= 0) {
      return;
    }

    if (gradientEndColor == null) {
      canvas.drawArc(rect, _startAngle, sweep, false, _fillPaint(rect));
      return;
    }

    // Soft glow underlay: a wider, blurred pass of the same arc in the
    // gradient's start colour — kept faint, because at a clamped 100% sweep
    // (盈余日) a stronger halo reads as a coloured blob rather than light.
    canvas.drawArc(
      rect,
      _startAngle,
      sweep,
      false,
      _fillPaint(
        rect,
        overrideColor: color.withValues(alpha: 0.22),
        widthFactor: 1.5,
        blurSigma: strokeWidth * 0.45,
      ),
    );
    canvas.drawArc(rect, _startAngle, sweep, false, _fillPaint(rect));
  }

  Paint _fillPaint(
    Rect rect, {
    Color? overrideColor,
    double widthFactor = 1,
    double blurSigma = 0,
  }) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * widthFactor
      ..strokeCap = StrokeCap.round;
    final Color? endColor = gradientEndColor;
    if (overrideColor != null) {
      paint.color = overrideColor;
    } else if (endColor != null) {
      // The gradient spans exactly the drawn sweep, so the arc tip always
      // lands on the accent colour whatever the progress.
      paint.shader = SweepGradient(
        startAngle: _startAngle,
        endAngle: _startAngle + 2 * 3.141592653589793 * progress,
        colors: <Color>[color, endColor],
      ).createShader(rect);
    } else {
      paint.color = color;
    }
    if (blurSigma > 0) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);
    }
    return paint;
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.gradientEndColor != gradientEndColor ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
