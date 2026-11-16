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
  final double units;
  final double flowers;
  final bool resting;
  final bool centered;
  final bool dark;
  final PlantPalette? palette;
  final double? flowerCount;
  @override
  void paint(Canvas canvas, Size size) {
    final colors =
        palette ??
        PlantPalette.forBrightness(dark ? Brightness.dark : Brightness.light);
    final scale = math.min(size.width / 160, size.height / 200);
    canvas.save();
    canvas.translate(
      (size.width - 160 * scale) / 2,
      (size.height - 200 * scale) / 2,
    );
    canvas.scale(scale);
    final p = Paint()..isAntiAlias = true;
    final u = units.clamp(0.0, 4.0);
    final height = 126 * math.pow(u / 4, .55).toDouble();
    final root = Offset(80, centered ? 108 + height / 2 : 174);
    canvas.drawOval(
      Rect.fromLTWH(47, root.dy - 4, 66, 12),
      p..color = colors.soil,
    );
    canvas.drawOval(
      Rect.fromLTWH(61, root.dy - 2, 38, 6),
      p..color = colors.soilDark,
    );
    if (u <= 0) {
      canvas.save();
      canvas.translate(80, root.dy - 5);
      canvas.rotate(-0.35);
      canvas.drawOval(Rect.fromLTWH(-11, -7, 22, 14), p..color = colors.seed);
      canvas.drawOval(
        Rect.fromLTWH(-6, -5, 10, 3),
        p..color = colors.seedLight,
      );
      canvas.restore();
      final blooms = flowerCount ?? flowers * 5;
      for (var i = 0; i < blooms.ceil(); i++) {
        _flower(
          canvas,
          p,
          Offset(95 + math.sin(i * 2.4) * 12, root.dy - 9 - (i % 3) * 5),
          (blooms - i).clamp(0.0, 1.0) * .65,
        );
      }
      canvas.restore();
      return;
    }
    if (u < .5) {
      canvas.save();
      canvas.translate(80, root.dy - 5);
      canvas.rotate(-.35);
      canvas.drawOval(
        Rect.fromLTWH(-11, -7, 22, 14),
        p..color = colors.seed.withValues(alpha: 1 - u / .5),
      );
      canvas.restore();
    }
    final top = Offset(81 + 3 * math.sin(u), root.dy - height);
    final stem = Path()
      ..moveTo(root.dx, root.dy)
      ..cubicTo(
        76,
        root.dy - height * .32,
        86,
        root.dy - height * .65,
        top.dx,
        top.dy,
      );
    canvas.drawPath(
      stem,
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 + u * 1.1
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(
          colors.stem,
          colors.trunk,
          ((u - 1.5) / 1.5).clamp(0.0, 1.0),
        )!,
    );
    p.style = PaintingStyle.fill;
    // A slim highlight makes the trunk legible without adding a hard outline.
    canvas.drawPath(
      stem,
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(.6, u * .35)
        ..color = colors.trunkLight.withValues(alpha: .65),
    );
    p.style = PaintingStyle.fill;
    final tips = <Offset>[top];
    for (var i = 0; i < 7; i++) {
      final strength = ((u - .15) * 1.45 - i * .68).clamp(0.0, 1.0);
      if (strength == 0) continue;
      final side = i.isEven ? -1.0 : 1.0;
      final y = root.dy - height * (.25 + i * .09);
      final base = Offset(79 + math.sin(i * 1.4) * 2, y);
      final length = (12 + u * 5) * strength;
      final tip = base.translate(
        side * length,
        -(resting ? length * .08 : length * .55),
      );
      final branching = ((u - 1.5) / .8).clamp(0.0, 1.0);
      final end = Offset.lerp(base, tip, branching)!;
      if (branching > 0) {
        canvas.drawLine(
          base,
          end,
          p
            ..style = PaintingStyle.stroke
            ..strokeWidth = (1.3 + u * .45) * branching
            ..color = colors.trunk,
        );
        p.style = PaintingStyle.fill;
      }
      _leaf(canvas, p, end, side * length * (1 - branching * .25), resting);
      if (branching > 0) {
        _leaf(
          canvas,
          p,
          end.translate(-side * 5 * branching, branching),
          -side * 10 * branching,
          resting,
        );
      }
      tips.add(tip);
    }
    if (u > 2) {
      final canopy = ((u - 2) / 2).clamp(0.0, 1.0);
      for (var i = 0; i < 9; i++) {
        final angle = (i / 8) * math.pi * 1.65 + math.pi * .67;
        final center = top.translate(
          math.cos(angle) * (17 + canopy * 24),
          8 + math.sin(angle) * (8 + canopy * 20),
        );
        final leaf = Path()
          ..moveTo(center.dx - 14 * canopy, center.dy + 9 * canopy)
          ..cubicTo(
            center.dx - 22 * canopy,
            center.dy - 8 * canopy,
            center.dx - 3 * canopy,
            center.dy - 23 * canopy,
            center.dx + 13 * canopy,
            center.dy - 13 * canopy,
          )
          ..cubicTo(
            center.dx + 29 * canopy,
            center.dy + 2 * canopy,
            center.dx + 12 * canopy,
            center.dy + 19 * canopy,
            center.dx - 14 * canopy,
            center.dy + 9 * canopy,
          );
        canvas.drawPath(
          leaf,
          p
            ..color = [
              colors.leafDark,
              colors.leafMid,
              colors.leafLight,
            ][i % 3].withValues(alpha: resting ? .74 : 1),
        );
        if (i.isEven) tips.add(center);
      }
    }
    _leaf(
      canvas,
      p,
      top.translate(0, 3),
      (10 + u * 2) * (u / .3).clamp(0.0, 1.0),
      resting,
    );
    final blooms = flowerCount ?? flowers * 5;
    for (var i = 0; i < blooms.ceil(); i++) {
      final visible = (blooms - i).clamp(0.0, 1.0);
      final target = tips[(i * 2) % tips.length];
      final ring = i ~/ tips.length;
      _flower(
        canvas,
        p,
        target.translate(math.sin(i * 2.4) * ring * 4, -3 - ring * 3),
        visible *
            (.72 + .28 * (u / 4)) *
            (blooms > 12 ? math.sqrt(12 / blooms).clamp(.25, 1) : 1),
      );
    }
    canvas.restore();
  }

  void _leaf(Canvas canvas, Paint p, Offset base, double length, bool droop) {
    final colors =
        palette ??
        PlantPalette.forBrightness(dark ? Brightness.dark : Brightness.light);
    final tip = base.translate(length, -length.abs() * (droop ? .12 : .62));
    final path = Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(
        base.dx + length * .15,
        tip.dy - length.abs() * .5,
        tip.dx,
        tip.dy,
      )
      ..quadraticBezierTo(
        base.dx + length * .8,
        base.dy + length.abs() * .3,
        base.dx,
        base.dy,
      );
    canvas.drawPath(
      path,
      p
        ..style = PaintingStyle.fill
        ..color = colors.leafMid.withValues(alpha: droop ? .72 : 1),
    );
    canvas.drawLine(
      base,
      tip,
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7
        ..color = colors.vein,
    );
    p.style = PaintingStyle.fill;
  }

  void _flower(Canvas canvas, Paint p, Offset center, double scale) {
    final colors =
        palette ??
        PlantPalette.forBrightness(dark ? Brightness.dark : Brightness.light);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    for (var i = 0; i < 5; i++) {
      final angle = i * math.pi * 2 / 5;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(math.cos(angle) * 5, math.sin(angle) * 5),
          width: 8,
          height: 9,
        ),
        p
          ..style = PaintingStyle.fill
          ..color = colors.petal,
      );
    }
    canvas.drawCircle(Offset.zero, 3.8, p..color = colors.pollen);
    canvas.drawCircle(Offset(-.7, -.8), 1.1, p..color = colors.highlight);
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
