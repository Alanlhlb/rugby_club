import 'package:flutter/material.dart';

class RugbyPitchBackground extends StatelessWidget {
  const RugbyPitchBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0A3D12),
                Color(0xFF115A1A),
                Color(0xFF0E4F16),
                Color(0xFF0A3D12),
              ],
              stops: [0.0, 0.3, 0.7, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Grass stripes (alternating mowing pattern)
              ...List.generate(16, (i) {
                final stripeH = h / 16;
                return Positioned(
                  top: i * stripeH,
                  left: 0,
                  right: 0,
                  height: stripeH,
                  child: Container(
                    color: i.isEven
                        ? Colors.white.withAlpha(8)
                        : Colors.black.withAlpha(12),
                  ),
                );
              }),
              // Vignette (edge darkening)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.9,
                      colors: [Colors.transparent, Colors.black.withAlpha(120)],
                    ),
                  ),
                ),
              ),
              // Field lines
              CustomPaint(painter: FieldPainter(), size: Size(w, h)),
            ],
          ),
        );
      },
    );
  }
}

class FieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final margin = w * 0.04;

    // ── Touchline border (field boundary) ──
    final borderPaint = Paint()
      ..color = Colors.white.withAlpha(60)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    final borderRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(margin, h * 0.02, w - margin * 2, h * 0.96),
      const Radius.circular(4),
    );
    canvas.drawRRect(borderRect, borderPaint);

    // ── In-goal areas (slightly different shade) ──
    final inGoal = Paint()
      ..color = Colors.white.withAlpha(10)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(margin, h * 0.02, w - margin * 2, h * 0.06),
      inGoal,
    );
    canvas.drawRect(
      Rect.fromLTWH(margin, h * 0.92, w - margin * 2, h * 0.06),
      inGoal,
    );

    // ── Solid lines (brighter for clarity) ──
    final solidLine = Paint()
      ..color = Colors.white.withAlpha(90)
      ..strokeWidth = 1.8;
    final dimLine = Paint()
      ..color = Colors.white.withAlpha(55)
      ..strokeWidth = 1.2;

    // Try lines (bold)
    canvas.drawLine(
      Offset(margin, h * 0.08),
      Offset(w - margin, h * 0.08),
      solidLine,
    );
    canvas.drawLine(
      Offset(margin, h * 0.92),
      Offset(w - margin, h * 0.92),
      solidLine,
    );

    // 22m lines
    canvas.drawLine(
      Offset(margin, h * 0.22),
      Offset(w - margin, h * 0.22),
      dimLine,
    );
    canvas.drawLine(
      Offset(margin, h * 0.78),
      Offset(w - margin, h * 0.78),
      dimLine,
    );

    // Halfway line (boldest)
    final halfPaint = Paint()
      ..color = Colors.white.withAlpha(120)
      ..strokeWidth = 2.5;
    canvas.drawLine(
      Offset(margin, h * 0.50),
      Offset(w - margin, h * 0.50),
      halfPaint,
    );

    // No centre circle — rugby doesn't have one

    // 10m lines (dashed, slightly brighter)
    final dash = Paint()
      ..color = Colors.white.withAlpha(45)
      ..strokeWidth = 1.0;
    for (double x = margin; x < w - margin; x += 10) {
      canvas.drawLine(Offset(x, h * 0.40), Offset(x + 5, h * 0.40), dash);
      canvas.drawLine(Offset(x, h * 0.60), Offset(x + 5, h * 0.60), dash);
    }

    // ── H-shaped goal posts ──
    final postPaint = Paint()
      ..color = Colors.white.withAlpha(80)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final gapW = w * 0.04;
    // Top goal
    canvas.drawLine(
      Offset(w / 2 - gapW, h * 0.08),
      Offset(w / 2 - gapW, h * 0.03),
      postPaint,
    );
    canvas.drawLine(
      Offset(w / 2 + gapW, h * 0.08),
      Offset(w / 2 + gapW, h * 0.03),
      postPaint,
    );
    canvas.drawLine(
      Offset(w / 2 - gapW, h * 0.055),
      Offset(w / 2 + gapW, h * 0.055),
      postPaint,
    ); // crossbar
    // Bottom goal
    canvas.drawLine(
      Offset(w / 2 - gapW, h * 0.92),
      Offset(w / 2 - gapW, h * 0.97),
      postPaint,
    );
    canvas.drawLine(
      Offset(w / 2 + gapW, h * 0.92),
      Offset(w / 2 + gapW, h * 0.97),
      postPaint,
    );
    canvas.drawLine(
      Offset(w / 2 - gapW, h * 0.945),
      Offset(w / 2 + gapW, h * 0.945),
      postPaint,
    ); // crossbar

    // ── 5m & 15m tick marks along try lines ──
    final tick = Paint()
      ..color = Colors.white.withAlpha(20)
      ..strokeWidth = 0.8;
    for (final yBase in [0.08, 0.92]) {
      final dir = yBase == 0.08 ? 1.0 : -1.0;
      // 5m marks
      for (double x = margin + w * 0.05; x < w - margin; x += w * 0.10) {
        canvas.drawLine(
          Offset(x, h * yBase),
          Offset(x, h * yBase + h * 0.012 * dir),
          tick,
        );
      }
    }

    // ── Line labels ──
    final labelStyle = TextStyle(
      color: Colors.white.withAlpha(30),
      fontSize: 9,
      fontWeight: FontWeight.w600,
      letterSpacing: 1,
    );
    void drawLabel(String text, double y) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(margin + 4, h * y - tp.height / 2));
    }

    drawLabel('22', 0.22);
    drawLabel('10', 0.40);
    drawLabel('½', 0.50);
    drawLabel('10', 0.60);
    drawLabel('22', 0.78);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
