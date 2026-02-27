import 'package:flutter/material.dart';

/// LifeFlow brand logo — a blood drop containing a heartbeat pulse line,
/// with flowing ripple lines beneath.
///
/// Symbolism:
///   • **Blood drop** — the gift of donation
///   • **Heartbeat pulse** — life being sustained / restored
///   • **Flow ripples** — the continuous movement of life between
///     donors and patients (the "flow" in LifeFlow)
class LifeFlowLogo extends StatelessWidget {
  /// Logical size (width = height).
  final double size;

  /// Primary colour of the drop. Defaults to `Colors.red.shade600`.
  final Color? color;

  /// When `true` the drop is white and the pulse line uses [color].
  /// Useful on dark / coloured backgrounds.
  final bool inverted;

  const LifeFlowLogo({
    super.key,
    this.size = 48,
    this.color,
    this.inverted = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LifeFlowLogoPainter(
          color: color ?? Colors.red.shade600,
          inverted: inverted,
        ),
        size: Size(size, size),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom painter
// ---------------------------------------------------------------------------

class _LifeFlowLogoPainter extends CustomPainter {
  final Color color;
  final bool inverted;

  _LifeFlowLogoPainter({required this.color, required this.inverted});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final dropColor = inverted ? Colors.white : color;
    final lineColor = inverted ? color : Colors.white;

    // ── Blood Drop ────────────────────────────────────────────
    final dropPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          dropColor,
          Color.lerp(dropColor, Colors.black, 0.18)!,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.88));

    final drop = Path()
      ..moveTo(w * 0.50, h * 0.03) // tip
      ..cubicTo(
        w * 0.50, h * 0.15,
        w * 0.88, h * 0.30,
        w * 0.86, h * 0.55,
      )
      ..cubicTo(
        w * 0.84, h * 0.76,
        w * 0.66, h * 0.87,
        w * 0.50, h * 0.87,
      )
      ..cubicTo(
        w * 0.34, h * 0.87,
        w * 0.16, h * 0.76,
        w * 0.14, h * 0.55,
      )
      ..cubicTo(
        w * 0.12, h * 0.30,
        w * 0.50, h * 0.15,
        w * 0.50, h * 0.03,
      )
      ..close();

    // Soft shadow beneath the drop
    canvas.drawPath(
      drop.shift(Offset(0, h * 0.015)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.03),
    );

    canvas.drawPath(drop, dropPaint);

    // Subtle highlight / sheen (top-left)
    canvas.save();
    canvas.clipPath(drop);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 0.55,
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(w * 0.14, h * 0.03, w * 0.72, h * 0.84)),
    );
    canvas.restore();

    // ── Heartbeat / ECG Pulse Line ────────────────────────────
    final strokeW = (w * 0.038).clamp(1.5, 4.0);
    final pulsePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final midY = h * 0.50;
    final pulse = Path()
      ..moveTo(w * 0.20, midY) // enter from left
      ..lineTo(w * 0.34, midY) // flat approach
      ..lineTo(w * 0.39, midY + h * 0.045) // Q dip
      ..lineTo(w * 0.47, midY - h * 0.155) // R peak (tall spike)
      ..lineTo(w * 0.54, midY + h * 0.070) // S dip
      ..lineTo(w * 0.59, midY) // baseline
      ..lineTo(w * 0.64, midY) // short flat
      ..quadraticBezierTo(
        w * 0.69,
        midY - h * 0.04,
        w * 0.73,
        midY,
      ) // T-wave bump
      ..lineTo(w * 0.82, midY); // flat exit

    canvas.drawPath(pulse, pulsePaint);

    // ── Flow Ripples (beneath drop) ───────────────────────────
    final flowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    flowPaint
      ..color = dropColor.withValues(alpha: 0.35)
      ..strokeWidth = (w * 0.022).clamp(1.0, 3.0);

    canvas.drawPath(
      Path()
        ..moveTo(w * 0.30, h * 0.91)
        ..quadraticBezierTo(w * 0.50, h * 0.87, w * 0.70, h * 0.93),
      flowPaint,
    );

    flowPaint
      ..color = dropColor.withValues(alpha: 0.20)
      ..strokeWidth = (w * 0.018).clamp(0.8, 2.5);

    canvas.drawPath(
      Path()
        ..moveTo(w * 0.36, h * 0.96)
        ..quadraticBezierTo(w * 0.50, h * 0.92, w * 0.64, h * 0.98),
      flowPaint,
    );
  }

  @override
  bool shouldRepaint(_LifeFlowLogoPainter old) =>
      old.color != color || old.inverted != inverted;
}
