import 'app_strings.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'growth_rules.dart';
import 'app_theme.dart';
import 'motion.dart';

double plantUnits(Duration minutes) {
  final stage = GrowthRules.stageFor(minutes);
  return stage.index +
      (stage == PlantStage.tree ? 0 : GrowthRules.progressWithinStage(minutes));
}

final plantStageLabels = GrowthRules.stageNames;

enum PlantVisualState { calm, breathing, growing, celebration, resting }

/// One vector illustration, shared by Home, focus, topics and the garden.
class PlantView extends StatefulWidget {
  const PlantView({
    super.key,
    required this.stage,
    this.progress = 0,
    this.size,
    this.flowerCount = 0,
    this.state = PlantVisualState.calm,
    this.centered = true,
    this.fromUnits,
    this.animate = true,
  });
  final PlantStage stage;
  final double progress;
  final double? size;
  final int flowerCount;
  final PlantVisualState state;
  final bool centered, animate;
  final double? fromUnits;
  double get units =>
      stage.index + (stage == PlantStage.tree ? 0 : progress.clamp(0.0, 1.0));
  @override
  State<PlantView> createState() => _PlantViewState();
}

class _PlantViewState extends State<PlantView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _celebration;
  bool _feedbackSent = false;
  bool _celebrationRequested = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _celebration = AnimationController(
      vsync: this,
      duration: GrowzaMotion.celebration,
    );
  }

  void _growthEnded() {
    if (!mounted || _feedbackSent || widget.state != PlantVisualState.growing) {
      return;
    }
    _feedbackSent = true;
    final changed =
        widget.fromUnits != null &&
        widget.units.floor() > widget.fromUnits!.floor();
    GrowzaMotion.feedback(context, stageChanged: changed);
    if (changed && !GrowzaMotion.reduced(context)) {
      _celebration.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(PlantView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.units != widget.units ||
        oldWidget.flowerCount != widget.flowerCount) {
      _feedbackSent = false;
    }
    if (oldWidget.state == PlantVisualState.resting &&
        widget.state != PlantVisualState.resting) {
      _celebration.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (GrowzaMotion.reduced(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _celebration.stop();
    } else if (widget.state == PlantVisualState.celebration &&
        !_celebrationRequested) {
      _celebrationRequested = true;
      _celebration.forward(from: 0);
      GrowzaMotion.feedback(context, stageChanged: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _celebration.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _celebration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = PlantPalette.of(context);
    final reduced = GrowzaMotion.reduced(context);
    final resting = widget.state == PlantVisualState.resting;
    final body = TweenAnimationBuilder<double>(
      tween: Tween(begin: widget.fromUnits ?? widget.units, end: widget.units),
      duration: reduced || !widget.animate
          ? Duration.zero
          : GrowzaMotion.growth,
      curve: widget.state == PlantVisualState.growing
          ? GrowzaMotion.growthCurve
          : Curves.easeOutCubic,
      onEnd: _growthEnded,
      builder: (context, value, _) => TweenAnimationBuilder<double>(
        tween: Tween(end: widget.flowerCount.toDouble()),
        duration: reduced || !widget.animate
            ? Duration.zero
            : GrowzaMotion.growth,
        curve: Curves.easeOutCubic,
        builder: (context, blooms, _) => CustomPaint(
          painter: StudyPlantPainter(
            value,
            blooms / 5,
            flowerCount: blooms,
            resting: resting,
            centered: widget.centered,
            dark: Theme.of(context).brightness == Brightness.dark,
            palette: palette,
          ),
          size: Size.infinite,
        ),
      ),
    );
    final illustration = RepaintBoundary(
      child: AnimatedOpacity(
        opacity: resting ? .82 : 1,
        duration: reduced ? Duration.zero : GrowzaMotion.numbers,
        child: body,
      ),
    );
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Semantics(
        image: true,
        label: tr(context, "{0}، {1} أزهار", [
          tr(context, plantStageLabels[widget.stage]!),
          widget.flowerCount,
        ]),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _celebration,
                builder: (context, _) => CustomPaint(
                  painter: _PlantCelebration(_celebration.value, palette),
                ),
              ),
            ),
            MotionLoop(
              active: widget.state == PlantVisualState.breathing || resting,
              child: illustration,
              builder: (context, child) {
                final phase = MotionLoop.phaseOf(context) * math.pi * 2;
                final wave = math.sin(phase);
                return Transform.scale(
                  scale: 1 + GrowzaMotion.breathScale * wave,
                  alignment: Alignment.bottomCenter,
                  child: Transform.rotate(
                    angle: wave * GrowzaMotion.swayRadians,
                    alignment: Alignment.bottomCenter,
                    child: child,
                  ),
                );
              },
            ),
            if (widget.state == PlantVisualState.growing)
              Align(
                alignment: Alignment.bottomCenter,
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _celebration,
                    curve: Curves.easeInOut,
                  ),
                  child: Text(
                    tr(context, plantStageLabels[widget.stage]!),
                    style: TextStyle(
                      color: palette.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PlantThumbnail extends StatelessWidget {
  const PlantThumbnail({
    super.key,
    required this.stage,
    this.progress = 0,
    this.flowerCount = 0,
    this.size = GrowzaLayout.thumbnail,
  });
  final PlantStage stage;
  final double progress, size;
  final int flowerCount;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: PlantView(
      stage: stage,
      progress: progress,
      flowerCount: flowerCount,
      animate: false,
    ),
  );
}

/// Compatibility adapter for existing focus/garden callers; no growth is calculated here.
class StudyPlant extends StatelessWidget {
  const StudyPlant({
    super.key,
    required this.units,
    required this.flowers,
    this.resting = false,
    this.animate = true,
    this.fromUnits,
    this.centered = false,
    this.flowerCount,
    this.visualState = PlantVisualState.calm,
  });
  final double units, flowers;
  final bool resting, animate, centered;
  final double? fromUnits;
  final int? flowerCount;
  final PlantVisualState visualState;
  @override
  Widget build(BuildContext context) {
    final clamped = units.clamp(0.0, 4.0);
    final index = clamped.floor();
    return PlantView(
      stage: PlantStage.values[index],
      progress: clamped - index,
      flowerCount: flowerCount ?? (flowers * 5).ceil(),
      centered: centered,
      fromUnits: fromUnits,
      animate: animate,
      state: resting ? PlantVisualState.resting : visualState,
    );
  }
}

class _PlantCelebration extends CustomPainter {
  const _PlantCelebration(this.phase, this.palette);
  final double phase;
  final PlantPalette palette;
  @override
  void paint(Canvas canvas, Size size) {
    if (phase <= 0 || phase >= 1) return;
    final center = Offset(size.width / 2, size.height * .43);
    final fade = math.sin(math.pi * phase);
    final p = Paint()
      ..shader =
          RadialGradient(
            colors: [
              palette.halo.withValues(alpha: fade * .26),
              palette.halo.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: size.shortestSide * .48),
          );
    canvas.drawCircle(center, size.shortestSide * .48, p);
    p.shader = null;
    for (var i = 0; i < GrowzaMotion.particleCount; i++) {
      final angle = i * math.pi * 2 / GrowzaMotion.particleCount;
      final position =
          center +
          Offset(
            math.cos(angle) * (30 + phase * 55),
            math.sin(angle) * 35 + phase * 35,
          );
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(angle + phase);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 3, height: 6),
        p..color = palette.leafLight.withValues(alpha: fade * .65),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PlantCelebration old) =>
      phase != old.phase || palette != old.palette;
}

class StudyPlantPainter extends CustomPainter {
  const StudyPlantPainter(
    this.units,
    this.flowers, {
    this.resting = false,
    this.centered = false,
    this.dark = false,
    this.palette,
    this.flowerCount,
  });
  final double units, flowers;
  final bool resting, centered, dark;
  final PlantPalette? palette;
  final double? flowerCount;
  PlantPalette get _colors =>
      palette ??
      PlantPalette.forBrightness(dark ? Brightness.dark : Brightness.light);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final colors = _colors;
    final scale = math.min(size.width / 160, size.height / 200);
    canvas.save();
    canvas.translate(
      (size.width - 160 * scale) / 2,
      (size.height - 200 * scale) / 2,
    );
    canvas.scale(scale);
    final u = units.isFinite ? units.clamp(0.0, 4.0) : 0.0;
    final height = 128 * math.pow(u / 4, .64).toDouble();
    final root = Offset(80, centered ? 110 + height * .46 : 174);
    final tip = Offset(80 + math.sin(u * 1.3) * 3, root.dy - height);
    final p = Paint()..isAntiAlias = true;
    // A soft, bounded wash provides depth without expensive blur layers.
    final halo = Rect.fromCenter(
      center: Offset(80, root.dy - height * .48 - 6),
      width: 122,
      height: math.max(66, height + 40),
    );
    canvas.drawOval(
      halo,
      p
        ..shader = RadialGradient(
          colors: [
            colors.halo.withValues(alpha: dark ? .09 : .11),
            colors.halo.withValues(alpha: 0),
          ],
        ).createShader(halo),
    );
    p.shader = null;
    canvas.drawOval(
      Rect.fromCenter(center: root.translate(0, 9), width: 83, height: 12),
      p..color = colors.soilDark.withValues(alpha: .14),
    );
    final mound = Path()
      ..moveTo(40, root.dy + 1)
      ..cubicTo(48, root.dy - 7, 65, root.dy - 9, 80, root.dy - 5)
      ..cubicTo(94, root.dy - 10, 112, root.dy - 5, 122, root.dy + 1)
      ..cubicTo(115, root.dy + 16, 47, root.dy + 18, 40, root.dy + 1)
      ..close();
    canvas.drawPath(
      mound,
      p
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(colors.soil, colors.highlight, .16)!,
            colors.soilDark.withValues(alpha: .65),
          ],
        ).createShader(Rect.fromLTWH(40, root.dy - 8, 82, 27)),
    );
    p.shader = null;
    // Delicate root threads and soil grains make even the seed a small scene.
    _stroke(
      canvas,
      Path()
        ..moveTo(80, root.dy)
        ..cubicTo(74, root.dy + 3, 83, root.dy + 7, 77, root.dy + 11),
      colors.seedLight.withValues(alpha: .7),
      .65,
    );
    for (var i = 0; i < 7; i++) {
      final x = 49.0 + i * 10;
      final y = root.dy + 4 + math.sin(i * 2.3) * 3;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: i.isEven ? 2.4 : 1.5,
          height: 1.1,
        ),
        p..color = colors.seed.withValues(alpha: .32),
      );
    }
    final seedAlpha = (1 - u / .7).clamp(0.0, 1.0);
    if (seedAlpha > 0) _seed(canvas, root.translate(0, -3), seedAlpha, u);
    final flowerTips = <Offset>[];
    if (u > 0) {
      final wood = ((u - 1.5) / 2.5).clamp(0.0, 1.0);
      final stemColor = Color.lerp(colors.stem, colors.trunk, wood)!;
      final stem = Path()
        ..moveTo(80, root.dy + 1)
        ..cubicTo(
          74,
          root.dy - height * .22,
          87,
          root.dy - height * .64,
          tip.dx,
          tip.dy,
        );
      _stroke(canvas, stem, stemColor, 1.35 + 4.5 * wood);
      _stroke(
        canvas,
        Path()
          ..moveTo(79.3, root.dy - 1)
          ..cubicTo(
            75.4,
            root.dy - height * .23,
            85,
            root.dy - height * .64,
            tip.dx - .5,
            tip.dy + 1,
          ),
        colors.trunkLight.withValues(alpha: .65),
        .55 + wood * .7,
      );
      // Paired cotyledons unfold first; mature foliage is built from branching twigs.
      for (var i = 0; i < 8; i++) {
        final strength = ((u - .10 - i * .31) / .62).clamp(0.0, 1.0);
        if (strength <= 0) continue;
        final side = i.isEven ? -1.0 : 1.0;
        final maturity = ((u - 3) / 1).clamp(0.0, 1.0);
        final fraction = .29 + i * .084 + maturity * .12 * (1 - i / 8);
        final origin = Offset(
          80 + math.sin(i * .9) * 1.8,
          root.dy - height * fraction,
        );
        final crown = (.88 + .12 * math.sin(i * .7));
        final reach = (12 + u * 5.4) * strength * crown * (1 + maturity * .32);
        final end = origin.translate(
          side * reach,
          -(5 + u * 4.2) * strength * (resting ? .75 : 1),
        );
        final branch = Path()
          ..moveTo(origin.dx, origin.dy)
          ..quadraticBezierTo(
            origin.dx + side * reach * .65,
            origin.dy - 2,
            end.dx,
            end.dy,
          );
        _stroke(canvas, branch, stemColor, (.65 + wood * 1.35) * strength);
        final angle = side < 0 ? -2.53 : -.70;
        final leafSize = (12 + u * 2.6) * strength;
        _leaf(canvas, end, leafSize, angle + (resting ? side * .18 : 0), i);
        flowerTips.add(end.translate(side * 6, -6));
        final fullness = ((u - 1.85 - i * .045) / 1.2).clamp(0.0, 1.0);
        if (fullness > 0) {
          final middle = Offset.lerp(origin, end, .63)!;
          _leaf(
            canvas,
            middle,
            (10 + u * 1.55) * strength * fullness,
            side < 0 ? -1.83 : -1.35,
            i + 1,
          );
          _leaf(
            canvas,
            end.translate(-side * 3, 2),
            (11 + u * 1.3) * strength * fullness,
            side < 0 ? 2.78 : .27,
            i + 2,
          );
          if (u > 3.1) {
            final extra = ((u - 3.1) / .9).clamp(0.0, 1.0);
            _leaf(
              canvas,
              Offset.lerp(origin, end, .38)!,
              12 * strength * extra,
              side < 0 ? -2.65 : -.45,
              i + 3,
            );
          }
        }
      }
      final bud = (u / .6).clamp(0.0, 1.0);
      _leaf(canvas, tip.translate(0, 4), (10 + u * 1.8) * bud, -1.86, 1);
      if (u > 1.2) {
        _leaf(
          canvas,
          tip.translate(0, 7),
          (10 + u) * ((u - 1.2) / .7).clamp(0.0, 1.0),
          -.75,
          2,
        );
      }
      flowerTips.add(tip.translate(2, -5));
    }
    // Moss is scenery rather than credited growth, with the seed partly buried.
    for (final item in [
      (54.0, -1.0, 7.0),
      (61.0, 1.0, 5.0),
      (105.0, 1.0, 6.0),
      (113.0, -1.0, 4.0),
    ]) {
      final (x, side, h) = item;
      _stroke(
        canvas,
        Path()
          ..moveTo(x, root.dy + 1)
          ..quadraticBezierTo(
            x + side * 1.8,
            root.dy - h * .7,
            x + side * 4,
            root.dy - h,
          ),
        colors.leafMid.withValues(alpha: .72),
        .8,
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: root.translate(0, 1), width: 13, height: 3.5),
      p..color = colors.soilDark.withValues(alpha: .7),
    );
    final requested = flowerCount ?? flowers * 5;
    final blooms = requested.isFinite ? requested.clamp(0.0, 24.0) : 0.0;
    if (flowerTips.isEmpty) {
      flowerTips.addAll([
        root.translate(-17, -9),
        root.translate(18, -10),
        root.translate(5, -15),
      ]);
    }
    for (var i = 0; i < blooms.ceil(); i++) {
      final pos = flowerTips[(i + flowerTips.length ~/ 2) % flowerTips.length];
      final ring = i ~/ flowerTips.length;
      final center = pos.translate(math.sin(i * 2.4) * ring * 5, -ring * 3.5);
      if (u == 0) {
        _stroke(
          canvas,
          Path()
            ..moveTo(center.dx, root.dy)
            ..quadraticBezierTo(
              center.dx + 2,
              center.dy + 3,
              center.dx,
              center.dy,
            ),
          colors.stem,
          .75,
        );
      }
      _flower(
        canvas,
        center,
        (blooms - i).clamp(0.0, 1.0) * (u == 0 ? .62 : .72 + u * .065),
      );
    }
    canvas.restore();
  }

  void _stroke(Canvas canvas, Path path, Color color, double width) {
    canvas.drawPath(
      path,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = width
        ..color = color,
    );
  }

  void _seed(Canvas canvas, Offset center, double alpha, double growth) {
    final c = _colors;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-.36);
    final seed = Path()
      ..moveTo(0, -9)
      ..cubicTo(6.2, -4.5, 6.2, 2, 0, 5)
      ..cubicTo(-5.7, 2, -5.7, -3.5, 0, -9)
      ..close();
    canvas.drawPath(
      seed,
      Paint()
        ..isAntiAlias = true
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.seedLight.withValues(alpha: alpha),
            c.seed.withValues(alpha: alpha),
          ],
        ).createShader(const Rect.fromLTWH(-5, -9, 11, 14)),
    );
    _stroke(
      canvas,
      Path()
        ..moveTo(0, -7)
        ..quadraticBezierTo(-1.8, -1, .4, 4),
      c.seed.withValues(alpha: alpha * .7),
      .6,
    );
    _stroke(
      canvas,
      Path()
        ..moveTo(-2, -5)
        ..quadraticBezierTo(-3.2, -2.2, -2.3, .3),
      c.highlight.withValues(alpha: alpha * .55),
      .65,
    );
    canvas.restore();
  }

  void _leaf(
    Canvas canvas,
    Offset base,
    double length,
    double angle,
    int tone,
  ) {
    if (length < .1) return;
    final c = _colors;
    final shade = [c.leafDark, c.leafMid, c.leafLight][tone % 3];
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(angle);
    final leaf = Path()
      ..moveTo(0, 0)
      ..cubicTo(
        length * .24,
        -length * .43,
        length * .7,
        -length * .31,
        length,
        0,
      )
      ..cubicTo(length * .64, length * .38, length * .25, length * .27, 0, 0)
      ..close();
    final bounds = Rect.fromLTWH(0, -length * .43, length, length * .81);
    canvas.drawPath(
      leaf,
      Paint()
        ..isAntiAlias = true
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(shade, c.leafLight, .38)!,
            shade,
            Color.lerp(shade, c.leafDark, .28)!,
          ],
        ).createShader(bounds),
    );
    _stroke(
      canvas,
      Path()
        ..moveTo(length * .08, 0)
        ..quadraticBezierTo(length * .48, -length * .035, length * .92, 0),
      c.vein.withValues(alpha: .58),
      .42,
    );
    if (length > 17) {
      for (final f in [.34, .56]) {
        _stroke(
          canvas,
          Path()
            ..moveTo(length * f, -.2)
            ..lineTo(length * (f + .13), -length * .13),
          c.vein.withValues(alpha: .28),
          .32,
        );
      }
    }
    if (tone == 1 && length > 15) {
      canvas.drawCircle(
        Offset(length * .62, -length * .11),
        .95,
        Paint()..color = c.highlight.withValues(alpha: .8),
      );
    }
    canvas.restore();
  }

  void _flower(Canvas canvas, Offset center, double scale) {
    if (scale <= 0) return;
    final c = _colors;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    for (var i = 0; i < 5; i++) {
      canvas.save();
      canvas.rotate(i * math.pi * 2 / 5 - .25);
      final petal = Path()
        ..moveTo(0, 1)
        ..cubicTo(-5.2, -1, -5, -8.8, 0, -9.8)
        ..cubicTo(5, -8.8, 5.2, -1, 0, 1)
        ..close();
      canvas.drawPath(
        petal,
        Paint()
          ..isAntiAlias = true
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c.highlight, c.petal],
          ).createShader(const Rect.fromLTWH(-5, -10, 10, 12)),
      );
      canvas.restore();
    }
    canvas.drawCircle(Offset.zero, 3, Paint()..color = c.pollen);
    canvas.drawCircle(const Offset(-.7, -.8), .8, Paint()..color = c.highlight);
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      canvas.drawCircle(
        Offset(math.cos(a) * 1.65, math.sin(a) * 1.65),
        .3,
        Paint()..color = c.seed.withValues(alpha: .6),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant StudyPlantPainter old) =>
      units != old.units ||
      flowers != old.flowers ||
      resting != old.resting ||
      centered != old.centered ||
      dark != old.dark ||
      palette != old.palette ||
      flowerCount != old.flowerCount;
}
