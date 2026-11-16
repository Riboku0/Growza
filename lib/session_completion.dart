import 'growth_rules.dart';

import 'package:flutter/material.dart';

import 'study_ui.dart';
import 'study_data.dart';
import 'focus_record.dart';
import 'growth_ledger.dart';
import 'plant_visual.dart';

class FocusReview {
  const FocusReview(this.topics, this.quality);
  final Set<int> topics;
  final FocusQuality quality;
}

class SessionCompletionScreen extends StatefulWidget {
  const SessionCompletionScreen({
    super.key,
    required this.subject,
    required this.record,
    required this.before,
    required this.after,
    this.notice,
    this.growthForQuality,
  });
  final StudySubject subject;
  final FocusRecord record;
  final PlantGrowth before;
  final PlantGrowth after;
  final String? notice;
  final PlantGrowth Function(FocusQuality)? growthForQuality;
  @override
  State<SessionCompletionScreen> createState() =>
      _SessionCompletionScreenState();
}

class _SessionCompletionScreenState extends State<SessionCompletionScreen> {
  final _selected = <int>{};
  FocusQuality? _quality;
  FocusQuality get _effectiveQuality => _quality ?? FocusQuality.full;
  PlantGrowth get _after =>
      widget.growthForQuality?.call(_effectiveQuality) ?? widget.after;

  String _growthMessage(BuildContext context) {
    if (widget.record.focused < GrowthRules.minimumGrowthSession) {
      return tr(
        context,
        'الجلسات الأقل من {0} دقائق لا تنمّي النبتة. وقتك محفوظ.',
        [GrowthRules.minimumGrowthSessionMinutes],
      );
    }
    final growth = _after.credited - widget.before.credited;
    if (growth == Duration.zero) return tr(context, 'حُفظ وقت تركيزك.');
    final minutes = growth.inSeconds / Duration.secondsPerMinute;
    return tr(context, 'نمت نبتتك {0} دقيقة.', [
      minutes.toStringAsFixed(
        growth.inSeconds % Duration.secondsPerMinute == 0 ? 0 : 1,
      ),
    ]);
  }

  String? _nextStageMessage(BuildContext context) {
    if (_after.stage == PlantStage.tree) return null;
    final stage = PlantStage.values[_after.stage.index + 1];
    final remaining =
        GrowthRules.stageThreshold(stage, target: _after.target) -
        _after.credited;
    return tr(context, 'تبقى {0} دقيقة لمرحلة {1}.', [
      (remaining.inSeconds / Duration.secondsPerMinute).ceil(),
      tr(context, GrowthRules.stageNames[stage]!),
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.subject.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 14),
      ),
      centerTitle: true,
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ScreenList(
              children: [
                Center(
                  child: Text(
                    tr(context, "وقت التركيز: {0} د", [
                      (widget.record.focused.inSeconds / 60).toStringAsFixed(
                        widget.record.focused.inSeconds % 60 == 0 ? 0 : 1,
                      ),
                    ]),
                    style: TextStyle(
                      fontSize: 14,
                      color: growzaColor(context, muted),
                    ),
                  ),
                ),
                SizedBox(
                  height: 220,
                  child: StudyPlant(
                    centered: true,
                    visualState: PlantVisualState.growing,
                    flowerCount:
                        widget.subject.completedCount + _selected.length,
                    key: ValueKey(widget.record.id),
                    fromUnits: widget.before.visualUnits,
                    units: _after.visualUnits,
                    flowers: _after.topicProgress,
                  ),
                ),
                Text(
                  _growthMessage(context),
                  key: const ValueKey('session-growth-result'),
                  textAlign: TextAlign.center,
                ),
                if (!widget.record.completed)
                  Text(
                    tr(context, 'هذه جلسة جزئية. حُفظ وقت تركيزك الفعلي.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: GrowzaPalette.of(context).secondaryText,
                    ),
                  ),
                if (_nextStageMessage(context) case final next?)
                  Text(
                    next,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: GrowzaPalette.of(context).secondaryText,
                    ),
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: [
                    Text(
                      tr(context, 'كيف كان تركيزك؟'),
                      key: const ValueKey('session-quality-question'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final quality in FocusQuality.values)
                          ChoiceChip(
                            key: ValueKey('quality-${quality.name}'),
                            label: Text(
                              tr(context, switch (quality) {
                                FocusQuality.full => 'كاملاً',
                                FocusQuality.half => 'نصفه',
                                FocusQuality.distracted => 'تشتّت',
                              }),
                            ),
                            selected: _quality == quality,
                            onSelected: (_) =>
                                setState(() => _quality = quality),
                          ),
                        TextButton(
                          key: const ValueKey('quality-skip'),
                          onPressed: () => setState(() => _quality = null),
                          child: Text(tr(context, 'تخطي التقييم')),
                        ),
                      ],
                    ),
                    Text(
                      tr(context, "هل أنهيت موضوعاً؟"),
                      key: ValueKey('session-review-question'),
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w600,
                        color: growzaColor(context, ink),
                      ),
                    ),
                  ],
                ),
                if (widget.subject.parts.every((p) => p.completed))
                  Text(
                    tr(context, "كل المواضيع الحالية مكتملة. حُفظ وقت تركيزك."),
                  ),
                for (final part in widget.subject.parts.where(
                  (p) => !p.completed,
                ))
                  CheckboxListTile(
                    key: ValueKey('review-topic-${part.id}'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(part.title),
                    value: _selected.contains(part.id),
                    onChanged: (selected) => setState(() {
                      if (selected == true) {
                        _selected.add(part.id);
                      } else {
                        _selected.remove(part.id);
                      }
                    }),
                  ),
              ],
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(22, 10, 22, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.notice != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          translatedMessage(context, widget.notice!),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: growzaColor(context, greenInk),
                            height: 1.5,
                          ),
                        ),
                      ),
                    StudyButton(
                      tr(context, "حفظ التقدم"),
                      _selected.isEmpty && _quality == null
                          ? null
                          : () => Navigator.pop(
                              context,
                              FocusReview(_selected, _effectiveQuality),
                            ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(
                        context,
                        FocusReview(<int>{}, _effectiveQuality),
                      ),
                      child: Text(tr(context, "لم أنهِ موضوعاً")),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
