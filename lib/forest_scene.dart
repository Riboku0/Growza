import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'motion.dart';

/// The approved flat-forest alternative. Scenery is cached separately from
/// one slowly moving butterfly; labels stay on an opaque theme surface.
class ForestScene extends StatelessWidget {
  const ForestScene({super.key, required this.child, this.motion = true});
  final Widget child;
  final bool motion;
  @override
  Widget build(BuildContext context) {
    final p = PlantPalette.of(context);
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(child: CustomPaint(painter: FlatForestPainter(p))),
          LayoutBuilder(
            builder: (context, bounds) => MotionLoop(
              active: motion,
              duration: GrowzaMotion.scenery,
              builder: (context, _) {
                final phase = MotionLoop.phaseOf(context);
                final angle = phase * math.pi * 2;
                return Align(
                  alignment: const AlignmentDirectional(-.6, -.32),
                  child: Transform.translate(
                    offset: Offset(
                      bounds.maxWidth * .055 * math.sin(angle),
                      bounds.maxHeight * .025 * math.sin(angle * 2),
                    ),
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _ButterflyPainter(p, phase),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class FlatForestPainter extends CustomPainter {
  const FlatForestPainter(this.palette);
  final PlantPalette palette;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..isAntiAlias = true;
    final w = size.width, h = size.height;
    final far = Path()
      ..moveTo(0, h * .52)
      ..cubicTo(w * .18, h * .20, w * .36, h * .42, w * .53, h * .34)
      ..cubicTo(w * .7, h * .23, w * .8, h * .36, w, h * .19)
      ..lineTo(w, h * .9)
      ..lineTo(0, h * .9)
      ..close();
    canvas.drawPath(far, p..color = palette.forest(.075));
    final near = Path()
      ..moveTo(0, h * .61)
      ..cubicTo(w * .26, h * .39, w * .39, h * .63, w * .64, h * .49)
      ..cubicTo(w * .84, h * .37, w * .94, h * .48, w, h * .44)
      ..lineTo(w, h * .9)
      ..lineTo(0, h * .9)
      ..close();
    canvas.drawPath(near, p..color = palette.forest(.13));
    for (var layer = 0; layer < 2; layer++) {
      for (var i = 0; i < 8; i++) {
        final edge = i < 4 ? i : (i - 4);
        final x = i < 4 ? edge * 21.0 - 8 : w - edge * 21.0 + 8;
        final height = 34 + (i % 4) * 14.0 + layer * 11;
        final bottom = h * (.77 + layer * .03) + math.sin(i * 2) * 4;
        _pine(
          canvas,
          p,
          x,
          bottom,
          height,
          palette.forest(.12 + layer * .075 + (i % 2) * .025),
        );
      }
    }
    final ground = Path()
      ..moveTo(0, h * .82)
      ..quadraticBezierTo(w * .44, h * .74, w, h * .83)
      ..lineTo(w, h * .92)
      ..quadraticBezierTo(w * .48, h * .88, 0, h * .94)
      ..close();
    canvas.drawPath(ground, p..color = palette.forest(.095));
    // A few soft blades at the edges, never around the main seed.
    p
      ..color = palette.forest(.21)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final x = i < 6 ? 9 + i * 12.0 : w - 9 - (i - 6) * 12;
      final y = h * .86 + math.sin(i) * 3;
      canvas.drawLine(Offset(x, y), Offset(x - 3, y - 7 - (i % 3) * 2), p);
      canvas.drawLine(Offset(x, y), Offset(x + 3, y - 5), p);
    }
  }

  void _pine(
    Canvas canvas,
    Paint p,
    double x,
    double bottom,
    double height,
    Color color,
  ) {
    p.color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 1.1, bottom - height, 2.2, height),
        const Radius.circular(2),
      ),
      p,
    );
    for (var b = 0; b < 3; b++) {
      final top = bottom - height + b * height * .21;
      final width = 10.0 + b * 4;
      final branch = Path()
        ..moveTo(x, top)
        ..quadraticBezierTo(
          x - width * .3,
          top + height * .16,
          x - width,
          top + height * .35,
        )
        ..quadraticBezierTo(
          x,
          top + height * .39,
          x + width,
          top + height * .35,
        )
        ..quadraticBezierTo(x + width * .3, top + height * .16, x, top)
        ..close();
      canvas.drawPath(branch, p);
    }
  }

  @override
  bool shouldRepaint(covariant FlatForestPainter old) => old.palette != palette;
}

class _ButterflyPainter extends CustomPainter {
  const _ButterflyPainter(this.palette, this.phase);
  final PlantPalette palette;
  final double phase;
  @override
  void paint(Canvas canvas, Size size) {
    final t = phase * math.pi * 2;
    final point = Offset(size.width / 2, size.height / 2);
    final p = Paint()..color = palette.petal.withValues(alpha: .8);
    canvas.save();
    canvas.translate(point.dx, point.dy);
    canvas.rotate(-.24 + math.sin(t) * .1);
    final wing = .55 + .35 * (.5 + .5 * math.sin(t * 18));
    canvas.scale(wing, 1);
    canvas.drawOval(const Rect.fromLTWH(-7, -6, 7, 10), p);
    canvas.drawOval(
      const Rect.fromLTWH(0, -5, 6, 9),
      p..color = palette.pollen.withValues(alpha: .75),
    );
    canvas.drawLine(
      const Offset(0, -4),
      const Offset(0, 5),
      p
        ..color = palette.trunk
        ..strokeWidth = 1.1,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ButterflyPainter old) =>
      old.phase != phase || old.palette != palette;
}
