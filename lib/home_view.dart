import 'package:flutter/material.dart';

import 'study_data.dart';
import 'exam_countdown.dart';
import 'growth_ledger.dart';
import 'growth_rules.dart';
import 'study_ui.dart';
import 'plant_visual.dart';
import 'forest_scene.dart';

/// Compatibility name retained for existing callers; this is an open scene,
/// with no card or photographic background.
class HomeProgressCard extends StatelessWidget {
  const HomeProgressCard({
    super.key,
    required this.subject,
    required this.wasStudied,
    required this.nextPart,
    required this.onOpen,
    required this.onAdd,
    this.now,
    this.hasSubjects = false,
    this.growth,
    this.onPreview,
    this.recommended = false,
  });
  final StudySubject? subject;
  final bool wasStudied, hasSubjects;
  final StudyPart? nextPart;
  final VoidCallback onOpen, onAdd;
  final VoidCallback? onPreview;
  final DateTime? now;
  final PlantGrowth? growth;
  final bool recommended;
  @override
  Widget build(BuildContext context) {
    final p = GrowzaPalette.of(context);
    final current = subject;
    final stage = growth?.stage ?? PlantStage.seed;
    final total = current?.parts.length ?? 0;
    return Column(
      key: ValueKey('home-progress-card'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (current != null)
          Text(
            recommended && current.exam != null
                ? tr(context, "مقترحة لقرب اختبارها")
                : wasStudied
                ? tr(context, "آخر مادة ذاكرتها")
                : tr(context, "ابدأ هنا"),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: p.secondaryText),
          ),
        SizedBox(
          height: current == null
              ? GrowzaLayout.seedHeight
              : GrowzaLayout.heroPlantHeight,
          child: ForestScene(
            child: Padding(
              padding: EdgeInsetsDirectional.symmetric(horizontal: 30),
              child: Semantics(
                button: current != null,
                label: current == null
                    ? tr(context, "بذرتك الأولى")
                    : tr(context, "عرض مراحل نمو {0}", [current.name]),
                child: Tooltip(
                  message: tr(context, "مراحل النمو"),
                  child: GestureDetector(
                    onTap: current == null ? null : onPreview,
                    child: PlantView(
                      key: ValueKey(
                        'home-focused-plant-${current?.id ?? 'empty'}',
                      ),
                      stage: stage,
                      progress: growth?.stageProgress ?? 0,
                      flowerCount: current?.completedCount ?? 0,
                      state: growth?.resting == true
                          ? PlantVisualState.resting
                          : PlantVisualState.breathing,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (current == null) ...[
          Text(
            hasSubjects
                ? tr(context, "مستعد لمادتك التالية؟")
                : tr(context, "كل رحلة تبدأ ببذرة."),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w600,
              color: p.foreground,
            ),
          ),
          SizedBox(height: 8),
          Text(
            hasSubjects
                ? tr(context, "نباتاتك المحصودة محفوظة في المنجزات.")
                : tr(context, "أضف مادة، وامنح بذرتك أول لحظة تركيز."),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: p.secondaryText),
          ),
          SizedBox(height: 16),
          StudyButton(
            hasSubjects
                ? tr(context, "أضف مادة")
                : tr(context, "أضف مادتك الأولى"),
            onAdd,
          ),
        ] else ...[
          TextButton(
            onPressed: onOpen,
            child: Text(
              current.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w700,
                color: p.foreground,
              ),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              Text(
                tr(context, plantStageLabels[stage]!),
                style: TextStyle(fontSize: 14, color: p.secondaryText),
              ),
              if (current.exam != null)
                MotionValue(
                  localizedCountdown(
                    context,
                    current.exam!,
                    now ?? DateTime.now(),
                  ),
                  key: ValueKey('home-exam-countdown'),
                  align: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: p.secondaryText),
                ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            total == 0
                ? tr(context, "لا توجد مواضيع بعد")
                : nextPart == null && growth?.focused == Duration.zero
                ? tr(context, "أنهيت مواضيعك، بقي أن تذاكر لتنمو نبتتك.")
                : nextPart == null
                ? tr(context, "أنجزت مواضيعك. نبتتك تحتفظ بكل جهدك.")
                : tr(context, "التالي · {0}", [nextPart!.title]),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: p.secondaryText),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Text(
                tr(context, "المواضيع"),
                style: TextStyle(fontSize: 13, color: p.secondaryText),
              ),
              SizedBox(width: 12),
              Expanded(
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : current.completedCount / total,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(4),
                  color: p.positiveText,
                  backgroundColor: p.subtle,
                ),
              ),
              SizedBox(width: 12),
              Text(
                tr(context, "{0} من {1}", [current.completedCount, total]),
                style: TextStyle(fontSize: 13, color: p.foreground),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class HomeSubjects extends StatelessWidget {
  const HomeSubjects({
    super.key,
    required this.subjects,
    required this.recentSubjects,
    required this.studiedNames,
    required this.onOpen,
    required this.onViewAll,
    this.selectedId,
    this.growthFor,
  });
  final List<StudySubject> subjects, recentSubjects;
  final List<String> studiedNames;
  final ValueChanged<StudySubject> onOpen;
  final VoidCallback onViewAll;
  final String? selectedId;
  final PlantGrowth Function(StudySubject)? growthFor;
  @override
  Widget build(BuildContext context) {
    final others = subjects.where((s) => s.id != selectedId).toList();
    if (others.isEmpty) {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: TextButton(
          onPressed: onViewAll,
          child: Text(tr(context, "عرض الكل")),
        ),
      );
    }
    final p = GrowzaPalette.of(context);
    return Column(
      key: ValueKey('home-subjects'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tr(context, "مواد أخرى"),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: p.foreground,
                ),
              ),
            ),
            TextButton(
              onPressed: onViewAll,
              child: Text(tr(context, "عرض الكل")),
            ),
          ],
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final subject in others)
                Padding(
                  padding: EdgeInsetsDirectional.only(end: 12),
                  child: Semantics(
                    button: true,
                    label: tr(context, "اختيار {0}", [subject.name]),
                    child: InkWell(
                      key: ValueKey('current-subject-${subject.name}'),
                      onTap: () => onOpen(subject),
                      borderRadius: BorderRadius.circular(
                        GrowzaLayout.buttonRadius,
                      ),
                      child: SizedBox(
                        width: 104,
                        child: Column(
                          children: [
                            PlantThumbnail(
                              stage:
                                  growthFor?.call(subject).stage ??
                                  PlantStage.seed,
                              progress:
                                  growthFor?.call(subject).stageProgress ?? 0,
                              flowerCount: subject.completedCount,
                            ),
                            SizedBox(height: 4),
                            Text(
                              subject.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: p.foreground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
