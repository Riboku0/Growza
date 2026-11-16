enum FocusQuality { full, half, distracted }

enum PlantStage { seed, sprout, plant, shrub, tree }

abstract final class GrowthRules {
  // Optional PDF assistance: local limits and estimates, never model estimates.
  static const pdfMinutesPerPage = 4;
  static const pdfMaxTitleCharacters = 120;
  static const pdfMaxTopicMinutes = 720;
  static const pdfMaxOutlineDepth = 12;
  static const pdfHeadingsPerPage = 2;
  static const pdfMaxHeadingCharacters = 300;
  static const pdfMaxBytes = 20 * 1024 * 1024;
  static const pdfMaxPages = 2000;
  static const pdfScanPages = 300;
  static const pdfMaxTextCharacters = 12000;
  static const pdfMaxTopics = 60;
  static const dailyGrowthLimitMinutes = 240;
  static const minimumGrowthSessionMinutes = 5;
  static const completionGraceFraction = 0.05;
  static const maximumCompletionGrace = Duration(minutes: 1);

  // Target and stage values are in minutes; legacy subjects without topics
  // retain the original 1200-minute target.
  static const targetMultiplier = 2.0;
  static const minTarget = 300;
  static const defaultTopicMinutes = 25;
  static const fallbackTargetMinutes = 1200;
  static const fallbackTarget = Duration(minutes: fallbackTargetMinutes);
  static const qualityPercentages = <FocusQuality, int>{
    FocusQuality.full: 100,
    FocusQuality.half: 60,
    FocusQuality.distracted: 25,
  };
  static const stageFractions = <PlantStage, double>{
    PlantStage.seed: 0,
    PlantStage.sprout: .05,
    PlantStage.plant: .2,
    PlantStage.shrub: .5,
    PlantStage.tree: 1,
  };

  static Duration targetForEstimates(Iterable<int> estimates) {
    final values = estimates.toList();
    if (values.isEmpty) return fallbackTarget;
    final total = values.fold<int>(
      0,
      (sum, minutes) => sum + (minutes > 0 ? minutes : defaultTopicMinutes),
    );
    final scaled = total * targetMultiplier;
    return Duration(
      microseconds:
          ((scaled < minTarget ? minTarget.toDouble() : scaled) *
                  Duration.microsecondsPerMinute)
              .round(),
    );
  }

  static Duration stageThreshold(
    PlantStage stage, {
    Duration target = fallbackTarget,
  }) {
    if (target <= Duration.zero) {
      throw ArgumentError.value(target, 'target', 'Must be positive');
    }
    return Duration(
      microseconds: (target.inMicroseconds * stageFractions[stage]!).round(),
    );
  }

  // Compatibility for generic previews; subject views use their own target.
  static Map<PlantStage, int> get stageMinutes => {
    for (final stage in PlantStage.values)
      stage: stageThreshold(stage).inMinutes,
  };

  static Duration qualityCredit(Duration actual, FocusQuality quality) =>
      Duration(
        microseconds:
            actual.inMicroseconds * qualityPercentages[quality]! ~/ 100,
      );

  static const stageNames = <PlantStage, String>{
    PlantStage.seed: 'بذرة',
    PlantStage.sprout: 'برعم',
    PlantStage.plant: 'نبتة',
    PlantStage.shrub: 'شجيرة',
    PlantStage.tree: 'شجرة',
  };

  static const dailyLimitMessage = 'نبتتك شبعت اليوم، ما زال وقتك محسوباً';

  static Duration get dailyGrowthLimit =>
      const Duration(minutes: dailyGrowthLimitMinutes);
  static Duration get minimumGrowthSession =>
      const Duration(minutes: minimumGrowthSessionMinutes);

  static Duration completionGrace(Duration planned) {
    final proportional = (planned.inMilliseconds * completionGraceFraction)
        .floor();
    return Duration(
      milliseconds: proportional.clamp(
        0,
        maximumCompletionGrace.inMilliseconds,
      ),
    );
  }

  static bool countsAsCompleted(Duration focused, Duration planned) =>
      focused >= planned - completionGrace(planned);

  static PlantStage stageFor(
    Duration creditedFocus, {
    Duration target = fallbackTarget,
  }) => PlantStage.values.reversed.firstWhere(
    (stage) => creditedFocus >= stageThreshold(stage, target: target),
    orElse: () => PlantStage.seed,
  );

  static double progressWithinStage(
    Duration creditedFocus, {
    Duration target = fallbackTarget,
  }) {
    final stage = stageFor(creditedFocus, target: target);
    if (stage == PlantStage.tree) return 1;
    final lower = stageThreshold(stage, target: target).inMicroseconds;
    final upper = stageThreshold(
      PlantStage.values[stage.index + 1],
      target: target,
    ).inMicroseconds;
    return ((creditedFocus.inMicroseconds - lower) / (upper - lower)).clamp(
      0.0,
      1.0,
    );
  }
}
