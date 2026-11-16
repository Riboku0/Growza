import 'study_data.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'study_ui.dart';
import 'growth_ledger.dart';
import 'growth_rules.dart';
import 'plant_visual.dart';

typedef GardenProgress = ({
  String id,
  String subject,
  int completed,
  int total,
  PlantGrowth growth,
});

class StudyGarden extends StatefulWidget {
  const StudyGarden({
    super.key,
    required this.progress,
    required this.onAddSubject,
    this.compact = false,
    this.showActivePlants = true,
  });
  final List<GardenProgress> progress;
  final VoidCallback onAddSubject;
  final bool compact;
  final bool showActivePlants;
  @override
  State<StudyGarden> createState() => _StudyGardenState();
}

class _StudyGardenState extends State<StudyGarden> {
  final Set<String> _newHarvests = {};
  @override
  void didUpdateWidget(StudyGarden oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = {
      for (final p in oldWidget.progress)
        if (p.growth.harvested) p.id,
    };
    _newHarvests.addAll(
      widget.progress
          .where((p) => p.growth.harvested && !old.contains(p.id))
          .map((p) => p.id),
    );
  }

  List<GardenProgress> get progress => widget.progress;
  bool get compact => widget.compact;
  bool get showActivePlants => widget.showActivePlants;
  @override
  Widget build(BuildContext context) {
    final active = progress.where((p) => !p.growth.harvested).toList();
    final harvested = progress.where((p) => p.growth.harvested).toList();
    return Column(
      key: ValueKey('open-study-garden'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showActivePlants) ...[
          Row(
            children: [
              Expanded(
                child: copy(
                  tr(context, "حديقة المذاكرة"),
                  20,
                  weight: FontWeight.w600,
                ),
              ),
              IconButton(
                tooltip: tr(context, "مراحل النمو"),
                icon: Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: growzaColor(context, muted),
                ),
                onPressed: () => showGrowthPreview(context),
              ),
            ],
          ),
          copy(
            tr(context, "التركيز ينمّي الساق، وإنجاز المواضيع يفتح الأزهار."),
            12,
            color: growzaColor(context, muted),
          ),
          SizedBox(height: 4),
          _GardenScene(progress: active, edgeBleed: compact ? 22 : 0),
          if (active.isEmpty) ...[
            copy(
              tr(
                context,
                "نباتاتك المحصودة محفوظة بالأسفل. مادة جديدة تعني بذرة جديدة.",
              ),
              13,
              color: growzaColor(context, muted),
            ),
          ],
        ],
        if (harvested.isNotEmpty)
          ExpansionTile(
            key: ValueKey('garden-achievements'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            shape: Border(),
            collapsedShape: Border(),
            title: Text(
              tr(context, "المنجزات · {0}", [harvested.length]),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              tr(context, "نباتات حُصدت بعد الاختبار"),
              style: TextStyle(
                fontSize: 12,
                color: growzaColor(context, muted),
              ),
            ),
            children: [
              for (final plant in harvested)
                TweenAnimationBuilder<double>(
                  key: ValueKey(
                    'harvest-motion-${plant.id}-${_newHarvests.contains(plant.id)}',
                  ),
                  tween: Tween(
                    begin:
                        _newHarvests.contains(plant.id) &&
                            !GrowzaMotion.reduced(context)
                        ? 0
                        : 1,
                    end: 1,
                  ),
                  duration: GrowzaMotion.reduced(context)
                      ? Duration.zero
                      : GrowzaMotion.celebration,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - value) * 12),
                      child: child,
                    ),
                  ),
                  child: ListTile(
                    key: ValueKey('harvested-${plant.id}'),
                    contentPadding: EdgeInsets.zero,
                    leading: SizedBox(
                      width: 48,
                      height: 56,
                      child: StudyPlant(
                        units: plant.growth.visualUnits,
                        flowers: plant.growth.topicProgress,
                        flowerCount: plant.completed,
                        centered: true,
                      ),
                    ),
                    title: Text(plant.subject),
                    subtitle: Text(
                      tr(
                        context,
                        "{0} · التركيز: {1} د\nالمواضيع المنجزة: {2} / {3}",
                        [
                          tr(context, plantStageLabels[plant.growth.stage]!),
                          plant.growth.focused.inMinutes,
                          plant.completed,
                          plant.total,
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _GardenScene extends StatelessWidget {
  const _GardenScene({required this.progress, this.edgeBleed = 0});
  final List<GardenProgress> progress;
  final double edgeBleed;
  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final height = 334.0 + math.max(0, textScale - 1) * 95;
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.maxWidth + edgeBleed * 2;
        final width = math.max(viewport, progress.length * 160.0);
        final slot = width / math.max(1, progress.length);
        return SizedBox(
          height: height,
          child: OverflowBox(
            minWidth: viewport,
            maxWidth: viewport,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                height: height,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _MeadowScenePainter(
                          progress.length,
                          dark: Theme.of(context).brightness == Brightness.dark,
                        ),
                      ),
                    ),
                    for (final (index, plant) in progress.indexed) ...[
                      PositionedDirectional(
                        start: slot * (index + .5) - 80,
                        top: 10,
                        width: 160,
                        height: 208,
                        child: Semantics(
                          label: tr(
                            context,
                            "{0}، {1}، دقائق النمو {2}، المواضيع المنجزة {3} من {4}",
                            [
                              plant.subject,
                              tr(
                                context,
                                plantStageLabels[plant.growth.stage]!,
                              ),
                              plant.growth.credited.inMinutes,
                              plant.completed,
                              plant.total,
                            ],
                          ),
                          image: true,
                          child: StudyPlant(
                            key: ValueKey('garden-plant-${plant.id}'),
                            units: plant.growth.visualUnits,
                            flowers: plant.growth.topicProgress,
                            flowerCount: plant.completed,
                            resting: plant.growth.resting,
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        start: slot * index + 10,
                        top: 234,
                        width: slot - 20,
                        child: Column(
                          children: [
                            Text(
                              plant.subject,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.3,
                                fontWeight: FontWeight.w600,
                                color: growzaColor(context, ink),
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              tr(context, "{0} · {1} د", [
                                tr(
                                  context,
                                  plantStageLabels[plant.growth.stage]!,
                                ),
                                plant.growth.credited.inMinutes,
                              ]),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: growzaColor(context, muted),
                              ),
                            ),
                            Text(
                              tr(
                                context,
                                plant.growth.lastFocusedAt == null
                                    ? 'لم تبدأ المذاكرة بعد'
                                    : 'آخر جلسة: {0}',
                                plant.growth.lastFocusedAt == null
                                    ? []
                                    : [
                                        dayLabel(
                                          context,
                                          plant.growth.lastFocusedAt!,
                                        ),
                                      ],
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: growzaColor(context, muted),
                              ),
                            ),
                            Text(
                              tr(context, "المواضيع: {0} / {1}{2}", [
                                plant.completed,
                                plant.total,
                                plant.growth.resting
                                    ? tr(context, " · مستريحة")
                                    : '',
                              ]),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: growzaColor(context, muted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MeadowScenePainter extends CustomPainter {
  const _MeadowScenePainter(this.plantCount, {this.dark = false});
  final bool dark;
  final int plantCount;
  @override
  void paint(Canvas canvas, Size size) {
    if (dark) {
      canvas.saveLayer(
        null,
        Paint()
          ..colorFilter = ColorFilter.matrix([
            .40,
            0,
            0,
            0,
            5,
            0,
            .42,
            0,
            0,
            6,
            0,
            0,
            .38,
            0,
            5,
            0,
            0,
            0,
            1,
            0,
          ]),
      );
    }
    final w = size.width;
    final paint = Paint()..isAntiAlias = true;
    canvas.drawCircle(
      Offset(w * 0.84, 44),
      25,
      paint..color = Color(0xffecebd9),
    );
    final far = Path()
      ..moveTo(0, 139)
      ..cubicTo(w * .16, 105, w * .26, 107, w * .42, 137)
      ..cubicTo(w * .64, 165, w * .74, 105, w, 130)
      ..lineTo(w, 208)
      ..lineTo(0, 208)
      ..close();
    canvas.drawPath(far, paint..color = Color(0xffe3ead7));
    final near = Path()
      ..moveTo(0, 168)
      ..cubicTo(w * .18, 149, w * .29, 164, w * .48, 166)
      ..cubicTo(w * .68, 175, w * .84, 143, w, 161)
      ..lineTo(w, 222)
      ..quadraticBezierTo(w * .5, 235, 0, 216)
      ..close();
    canvas.drawPath(
      near,
      paint
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xffcbdab8), Color(0xffdbe4ca)],
        ).createShader(Rect.fromLTWH(0, 145, w, 86)),
    );
    paint.shader = null;
    final path = Path()
      ..moveTo(w * .67, 146)
      ..cubicTo(w * .61, 164, w * .42, 169, w * .47, 186)
      ..cubicTo(w * .51, 202, w * .70, 209, w * .69, 227)
      ..lineTo(w * .61, 226)
      ..cubicTo(w * .64, 211, w * .44, 207, w * .42, 188)
      ..cubicTo(w * .40, 168, w * .60, 160, w * .65, 147)
      ..close();
    canvas.drawPath(path, paint..color = Color(0xffeee6cd));
    for (var i = 0; i < plantCount; i++) {
      final x = w * (i + .5) / plantCount;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 190), width: 51, height: 13),
        paint..color = Color(0xffb5c59f),
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 190), width: 31, height: 7),
        paint..color = Color(0xff9baa84),
      );
    }
    for (var i = 0; i < (w / 18).floor(); i++) {
      final x = (i * 31.7) % w;
      final y = 178 + (math.sin(i * 2.4) + 1) * 18;
      final h = 8 + (i % 5) * 2.2;
      final blade = Path()
        ..moveTo(x - 3, y)
        ..quadraticBezierTo(x - 9, y - h * .45, x - 8, y - h)
        ..quadraticBezierTo(x - 2, y - h * .62, x, y - 2)
        ..quadraticBezierTo(x - 1, y - h * 1.25, x + 4, y - h * 1.4)
        ..quadraticBezierTo(x + 6, y - h * .5, x + 3, y - 1)
        ..quadraticBezierTo(x + 10, y - h * .7, x + 12, y - h * .45)
        ..quadraticBezierTo(x + 9, y - 1, x + 2, y + 1)
        ..close();
      canvas.drawPath(
        blade,
        paint
          ..color = [
            Color(0xff8eaa78),
            Color(0xffa8bd91),
            Color(0xff7f9d6c),
          ][i % 3].withValues(alpha: .75),
      );
    }
    for (var i = 0; i < 10; i++) {
      final x = w * ((i * .137 + .08) % 1);
      final y = 199 + math.sin(i * 1.8) * 14;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 4, height: 2),
        paint..color = Color(0xffedf0db),
      );
    }
    _butterfly(canvas, Offset(w * .26, 82), Color(0xffc9957c));
    _butterfly(canvas, Offset(w * .75, 103), Color(0xffb8a563));
    if (dark) canvas.restore();
  }

  void _butterfly(Canvas canvas, Offset point, Color color) {
    final p = Paint()..color = color.withValues(alpha: .8);
    canvas.save();
    canvas.translate(point.dx, point.dy);
    canvas.rotate(-.25);
    canvas.drawOval(Rect.fromLTWH(-7, -6, 7, 9), p);
    canvas.drawOval(Rect.fromLTWH(0, -5, 6, 8), p);
    canvas.drawLine(
      Offset(0, -3),
      Offset(0, 4),
      p
        ..color = Color(0xff7c8063)
        ..strokeWidth = 1,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MeadowScenePainter oldDelegate) =>
      oldDelegate.plantCount != plantCount || oldDelegate.dark != dark;
}

class _GrowthPreview extends StatefulWidget {
  const _GrowthPreview({
    this.subjectName,
    this.target = GrowthRules.fallbackTarget,
    this.noTopics = false,
  });
  final String? subjectName;
  final Duration target;
  final bool noTopics;
  @override
  State<_GrowthPreview> createState() => _GrowthPreviewState();
}

class _GrowthPreviewState extends State<_GrowthPreview> {
  var _stage = PlantStage.tree;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: EdgeInsetsDirectional.fromSTEB(22, 0, 22, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 460),
          child: Column(
            children: [
              copy(tr(context, "مراحل النمو"), 24, weight: FontWeight.w600),
              if (widget.subjectName case final name?)
                copy(name, 18, weight: FontWeight.w600),
              if (widget.subjectName != null) ...[
                const SizedBox(height: 8),
                copy(
                  widget.noTopics
                      ? tr(
                          context,
                          'بلا مواضيع بعد: يبقى هدف النمو {0} دقيقة، ونموك السابق محفوظ.',
                          [GrowthRules.fallbackTargetMinutes],
                        )
                      : tr(
                          context,
                          'هدف المادة: {0} دقيقة · المضاعف {1} · الحد الأدنى {2}',
                          [
                            _minutes(widget.target),
                            GrowthRules.targetMultiplier,
                            GrowthRules.minTarget,
                          ],
                        ),
                  13,
                  align: TextAlign.center,
                  color: growzaColor(context, muted),
                ),
              ],
              SizedBox(height: 8),
              copy(
                tr(
                  context,
                  "التركيز ينمّي الساق، وإنجاز المواضيع يفتح الأزهار. تستريح النباتات أثناء غيابك، ولا تفقد نموها.",
                ),
                13,
                color: growzaColor(context, muted),
                align: TextAlign.center,
              ),
              SizedBox(
                height: 240,
                width: 280,
                child: StudyPlant(
                  key: ValueKey(_stage),
                  units: _stage.index.toDouble(),
                  flowers: 1,
                  centered: true,
                ),
              ),
              copy(
                tr(context, "{0} · {1} دقيقة", [
                  tr(context, plantStageLabels[_stage]!),
                  _minutes(
                    GrowthRules.stageThreshold(_stage, target: widget.target),
                  ),
                ]),
                18,
                weight: FontWeight.w600,
              ),
              SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final stage in PlantStage.values)
                    ChoiceChip(
                      avatar: PlantThumbnail(
                        stage: stage,
                        flowerCount: 0,
                        size: 36,
                      ),
                      label: Text(
                        tr(context, "{0} {1} دقيقة", [
                          tr(context, plantStageLabels[stage]!),
                          _minutes(
                            GrowthRules.stageThreshold(
                              stage,
                              target: widget.target,
                            ),
                          ),
                        ]),
                      ),
                      selected: stage == _stage,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _stage = stage),
                    ),
                ],
              ),
              SizedBox(height: 14),
              copy(
                tr(
                  context,
                  "سقف النمو اليومي {0} دقيقة لكل المواد معاً. يستمر احتساب وقتك والمواضيع المنجزة بعده.",
                  [GrowthRules.dailyGrowthLimitMinutes],
                ),
                12,
                color: growzaColor(context, muted),
                align: TextAlign.center,
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr(context, "العودة للحديقة")),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _minutes(Duration value) =>
    (value.inMicroseconds / Duration.microsecondsPerMinute).toStringAsFixed(
      value.inMicroseconds % Duration.microsecondsPerMinute == 0 ? 0 : 1,
    );

void showGrowthPreview(
  BuildContext context, {
  String? subjectName,
  Duration target = GrowthRules.fallbackTarget,
  bool noTopics = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  backgroundColor: growzaColor(context, canvas),
  builder: (_) => _GrowthPreview(
    subjectName: subjectName,
    target: target,
    noTopics: noTopics,
  ),
);
