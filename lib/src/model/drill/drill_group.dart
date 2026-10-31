import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:lichess_mobile/src/model/drill/drill_chart.dart';
import 'package:lichess_mobile/src/model/drill/drill_controller.dart';
import 'package:lichess_mobile/src/model/drill/drill_history.dart';

/// Several Drills of the same theme and difficulty taken as one bigger Drill, each puzzle counting
/// the same, for one Drill Summary of them all.
///
/// Only Drills that [canBeGrouped] are: with other themes or difficulties, a figure of them all
/// would hide how differently they went. They are selected in the Drill History, or picked among
/// the [DrillGroupChoice]s of a range of days.
class const DrillGroup(
  /// The Drills, oldest first.
  final IList<Drill> drills,
) {
  /// Whether Drills with [configs] can be analyzed together: there are two at least, all of the
  /// same theme and difficulty.
  static bool canBeGrouped(Iterable<DrillConfig> configs) {
    final first = configs.firstOrNull;
    return configs.length >= 2 &&
        configs.every((c) => c.angle == first!.angle && c.difficulty == first.difficulty);
  }

  DrillConfig get config => drills.first.config;

  /// The outcome of each puzzle of the Drills, in order.
  IList<DrillPuzzleResult> get results => drills.expand((d) => d.results).toIList();

  int get successes => drills.map((d) => d.successes).sum;

  int get nbPlayed => drills.map((d) => d.results.length).sum;

  /// The share of puzzles solved, from 0 to 1, or 0 if no puzzle was solved.
  double get successRate => nbPlayed == 0 ? 0 : successes / nbPlayed;

  /// The Drill Performance of all the puzzles, see [Drill.performance].
  int? get performance => drillPerformance(results);

  bool get isPerformanceReliable => nbPlayed >= kMinReliableDrillPuzzles;

  /// The share of puzzles the player was expected to solve, each against the rating the player had
  /// when its Drill started, or `null` if a Drill's is unknown or no puzzle was solved.
  double? get expectedSuccessRate {
    if (nbPlayed == 0 || drills.any((d) => d.ratingBefore == null)) return null;
    return [
      for (final drill in drills)
        for (final r in drill.results) expectedPuzzleScore(drill.ratingBefore!, r.puzzleRating),
    ].average;
  }

  /// The sum of the Drills' rating changes, or `null` until every result is synced.
  ///
  /// The rating before the first Drill and after the last one are left out: the puzzles solved
  /// elsewhere between the Drills, such as in the official app, changed it too.
  int? get ratingChange {
    final changes = drills.map((d) => d.ratingChange);
    return changes.any((c) => c == null) ? null : changes.nonNulls.sum;
  }

  /// The time spent solving the puzzles.
  Duration get totalSolvingTime => drills.fold(.zero, (total, d) => total + d.totalSolvingTime);

  /// The average time spent solving a puzzle, or zero if no puzzle was solved.
  Duration get averageSolvingTime => nbPlayed == 0 ? .zero : totalSolvingTime ~/ nbPlayed;

  /// The themes most frequent among the failed puzzles, see [weakestThemesOf].
  IList<DrillWeakTheme> get weakestThemes => weakestThemesOf(results);
}

/// A range of days of the Drill History, both included: from [first], or the first Drill when
/// `null`, to [last].
typedef DrillDays = ({DateTime? first, DateTime last});

/// The days of [range] up to [today], as the charts of the Drill History count them.
DrillDays drillDaysOf(DrillChartRange range, {required DateTime today}) => (
  first: switch (range.nbDays) {
    final nbDays? => DateTime(today.year, today.month, today.day - (nbDays - 1)),
    null => null,
  },
  last: DateTime(today.year, today.month, today.day),
);

/// The Drills of a range of days of one theme and difficulty, Partial Drills included, to analyze
/// them together as a [DrillGroup] if they [canBeAnalyzed].
class const DrillGroupChoice(
  /// The summaries of the Drills, newest first, never empty.
  final IList<DrillHistoryEntry> entries,
) {
  DrillConfig get config => entries.first.config;

  /// Whether the Drills can be analyzed together: there are two at least, see
  /// [DrillGroup.canBeGrouped].
  bool get canBeAnalyzed => DrillGroup.canBeGrouped(entries.map((e) => e.config));

  /// When the Drills started, the key of their [DrillGroup].
  ISet<DateTime> get startedAts => entries.map((e) => e.startedAt).toISet();

  int get nbDrills => entries.length;

  int get nbPlayed => entries.map((e) => e.nbPlayed).sum;

  int get successes => entries.map((e) => e.successes).sum;

  /// The share of puzzles solved, from 0 to 1, or 0 if no puzzle was solved.
  double get successRate => nbPlayed == 0 ? 0 : successes / nbPlayed;
}

/// The Drills of [entries] by theme and difficulty: first those that can be analyzed together,
/// then the most puzzles first, then the most recent first.
IList<DrillGroupChoice> drillGroupChoicesOf(Iterable<DrillHistoryEntry> entries) {
  final sorted = entries.sorted((a, b) => b.startedAt.compareTo(a.startedAt));
  final choices = [
    for (final group in groupBy(sorted, (e) => (e.config.angle, e.config.difficulty)).values)
      DrillGroupChoice(group.toIList()),
  ];
  return choices.sorted((a, b) {
    if (a.canBeAnalyzed != b.canBeAnalyzed) return a.canBeAnalyzed ? -1 : 1;
    if (a.nbPlayed != b.nbPlayed) return b.nbPlayed.compareTo(a.nbPlayed);
    return b.entries.first.startedAt.compareTo(a.entries.first.startedAt);
  }).toIList();
}
