import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lichess_mobile/src/model/drill/drill_history.dart';
import 'package:lichess_mobile/src/model/settings/preferences_storage.dart';

part 'drill_chart.freezed.dart';
part 'drill_chart.g.dart';

/// The days the charts of the Drill History show, up to today, as in the puzzle rating history of
/// the profile.
enum DrillChartRange(
  /// How many days, today included, or `null` for the whole Drill History.
  final int? nbDays,
) {
  week(7),
  month(30),
  threeMonths(91),
  year(365),
  all(null),
}

/// What each value of the charts of the Drill History stands for.
enum DrillChartGrouping() {
  day,
  week,
  month,
}

/// The longest range grouped by day: a longer one is grouped by week.
const kMaxDrillChartDaysSpan = 91;

/// The longest Drill History grouped by week when all of it is shown: a longer one is grouped by
/// month.
const kMaxDrillChartWeeksSpan = 548;

/// A value of the charts of the Drill History: the Drills of a day, week or month taken as one
/// bigger Drill, each puzzle counting the same.
typedef DrillChartValue = ({
  /// The first day of its day, week or month.
  DateTime date,

  /// Its place on the chart: the number of days, weeks or months since the chart's start.
  int slot,

  /// The Drill Performance of its puzzles.
  double performance,

  /// The share of its puzzles solved, from 0 to 1.
  double successRate,

  /// The share of its puzzles the player was expected to solve, or `null` if a Drill doesn't have
  /// it.
  double? expected,
  int nbDrills,
  int nbPuzzles,
});

/// The values of the charts of the Drill History for a range.
class const DrillChartSeries({
  /// The days, weeks or months played, oldest first.
  required final IList<DrillChartValue> values,
  required final DrillChartGrouping grouping,

  /// The first day of the chart's first day, week or month.
  required final DateTime start,

  /// How many days, weeks or months the chart spans, from [start] to today's.
  required final int nbSlots,

  /// The Drills of the days of the range taken as one, or `null` if there are none: those of a
  /// first week or month taken whole are left out.
  required final DrillChartValue? total,

  /// The Drills of as many days just before the range taken as one, or `null` if there are none or
  /// the range is the whole Drill History.
  required final DrillChartValue? previous,
});

/// The ranges [points] covers, as in the puzzle rating history of the profile: those that start
/// after its first Drill, and the whole Drill History.
IList<DrillChartRange> drillChartRanges(IList<DrillChartPoint> points, {required DateTime today}) {
  final first = points.firstOrNull;
  return DrillChartRange.values
      .where(
        (range) => switch (range.nbDays) {
          final nbDays? =>
            first != null && !_day(first.startedAt).isAfter(_daysBefore(_day(today), nbDays - 1)),
          null => true,
        },
      )
      .toIList();
}

/// The values the charts of the Drill History draw for the days of [range] up to [today], from
/// the Drills' [points], oldest first.
///
/// A range of up to [kMaxDrillChartDaysSpan] days is grouped by day, a longer one by week, and
/// the whole Drill History by month when it spans more than [kMaxDrillChartWeeksSpan] days. The
/// first week or month is taken whole, so that it doesn't stand for only a few days. Each puzzle
/// counts the same: a Drill of 30 puzzles weighs three times one of 10.
///
/// The averages of the range, and of as many days before to compare them with, are of its days
/// only.
DrillChartSeries drillChartSeries(
  IList<DrillChartPoint> points, {
  required DrillChartRange range,
  required DateTime today,
}) {
  final lastDay = _day(today);
  final firstDay = drillChartRangeStart(points, range: range, today: today);
  final span = _daysBetween(firstDay, lastDay) + 1;
  final grouping = span <= kMaxDrillChartDaysSpan
      ? DrillChartGrouping.day
      : range == .all && span > kMaxDrillChartWeeksSpan
      ? DrillChartGrouping.month
      : DrillChartGrouping.week;

  DateTime groupStart(DateTime date) {
    final day = _day(date);
    return switch (grouping) {
      .day => day,
      .week => _daysBefore(day, day.weekday - DateTime.monday),
      .month => DateTime(day.year, day.month),
    };
  }

  final start = groupStart(firstDay);
  int slotOf(DateTime date) => switch (grouping) {
    .day => _daysBetween(start, date),
    .week => _daysBetween(start, date) ~/ 7,
    .month => (date.year - start.year) * 12 + date.month - start.month,
  };

  Iterable<DrillChartPoint> between(DateTime first, DateTime last) =>
      points.where((p) => !_day(p.startedAt).isBefore(first) && !_day(p.startedAt).isAfter(last));
  final shown = between(start, lastDay);
  final groups = groupBy(shown, (p) => groupStart(p.startedAt));
  return DrillChartSeries(
    values: [
      for (final MapEntry(key: date, value: group) in groups.entries)
        ?_pool(group, date: date, slot: slotOf(date)),
    ].toIList(),
    grouping: grouping,
    start: start,
    nbSlots: slotOf(groupStart(lastDay)) + 1,
    total: _pool(between(firstDay, lastDay), date: firstDay, slot: 0),
    previous: switch (range.nbDays) {
      final nbDays? => _pool(
        between(_daysBefore(firstDay, nbDays), _daysBefore(firstDay, 1)),
        date: _daysBefore(firstDay, nbDays),
        slot: 0,
      ),
      null => null,
    },
  );
}

/// [points] taken as one Drill, or `null` if they have no puzzles.
DrillChartValue? _pool(
  Iterable<DrillChartPoint> points, {
  required DateTime date,
  required int slot,
}) {
  final played = points.where((p) => p.nbPuzzles > 0 && p.performance != null).toList();
  final nbPuzzles = played.map((p) => p.nbPuzzles).sum;
  if (nbPuzzles == 0) return null;
  double weighted(double Function(DrillChartPoint p) value) =>
      played.map((p) => value(p) * p.nbPuzzles).sum / nbPuzzles;
  // A Drill's performance is linear in its puzzles' average rating and share solved, so their
  // weighted average is the performance of all the puzzles.
  return (
    date: date,
    slot: slot,
    performance: weighted((p) => p.performance!.toDouble()),
    successRate: weighted((p) => p.successRate),
    expected: played.every((p) => p.expectedSuccessRate != null)
        ? weighted((p) => p.expectedSuccessRate!)
        : null,
    nbDrills: played.length,
    nbPuzzles: nbPuzzles,
  );
}

/// The streaks of days in a row with a Drill: the [current] one, the [best] one, and whether
/// today is [playedToday].
typedef DrillStreak = ({int current, int best, bool playedToday});

/// The streaks of days in a row on which a Drill of [points] was played, a puzzle at least.
///
/// The current streak goes on until a whole day passes without a Drill: if today has none yet,
/// it is the one that ended yesterday.
DrillStreak drillStreak(IList<DrillChartPoint> points, {required DateTime today}) {
  final days = drillPuzzlesByDay(points).keys.toSet();
  final lastDay = _day(today);
  final playedToday = days.contains(lastDay);
  var current = 0;
  for (
    var day = playedToday ? lastDay : _daysBefore(lastDay, 1);
    days.contains(day);
    day = _daysBefore(day, 1)
  ) {
    current++;
  }
  var best = 0;
  var run = 0;
  DateTime? previous;
  for (final day in days.sorted((a, b) => a.compareTo(b))) {
    run = previous != null && _daysBetween(previous, day) == 1 ? run + 1 : 1;
    best = math.max(best, run);
    previous = day;
  }
  return (current: current, best: best, playedToday: playedToday);
}

/// The number of puzzles of the Drills of [points] played on each day, the days without any left
/// out.
IMap<DateTime, int> drillPuzzlesByDay(IList<DrillChartPoint> points) {
  final byDay = <DateTime, int>{};
  for (final point in points.where((p) => p.nbPuzzles > 0)) {
    final day = _day(point.startedAt);
    byDay[day] = (byDay[day] ?? 0) + point.nbPuzzles;
  }
  return byDay.lock;
}

/// The first day of [range] up to [today], or of the first Drill of [points] for the whole Drill
/// History.
DateTime drillChartRangeStart(
  IList<DrillChartPoint> points, {
  required DrillChartRange range,
  required DateTime today,
}) => switch (range.nbDays) {
  final nbDays? => _daysBefore(_day(today), nbDays - 1),
  null => points.isEmpty ? _day(today) : _day(points.first.startedAt),
};

DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime _daysBefore(DateTime day, int nbDays) => DateTime(day.year, day.month, day.day - nbDays);

/// The number of days from [from] to [to], whatever the daylight saving time changes between.
int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// What the charts of the Drill History show, remembered from the last time.
final drillChartPreferencesProvider = NotifierProvider<DrillChartPreferences, DrillChartPrefs>(
  DrillChartPreferences.new,
  name: 'DrillChartPreferencesProvider',
);

class DrillChartPreferences()
    extends Notifier<DrillChartPrefs>
    with PreferencesStorage<DrillChartPrefs> {
  @override
  @protected
  PrefCategory get prefCategory => PrefCategory.drillChart;

  @override
  @protected
  DrillChartPrefs get defaults => const DrillChartPrefs();

  @override
  DrillChartPrefs fromJson(Map<String, dynamic> json) => DrillChartPrefs.fromJson(json);

  @override
  DrillChartPrefs build() => fetch();

  Future<void> setRange(DrillChartRange range) => save(state.copyWith(range: range));
}

@Freezed(fromJson: true, toJson: true)
sealed class DrillChartPrefs with _$DrillChartPrefs implements Serializable {
  const factory({
    // The ranges of the last 10 or 30 Drills were replaced by ranges of days: one of them is the
    // last month.
    @JsonKey(unknownEnumValue: DrillChartRange.month)
    @Default(DrillChartRange.month)
    DrillChartRange range,
  }) = _DrillChartPrefs;

  factory fromJson(Map<String, dynamic> json) => _$DrillChartPrefsFromJson(json);
}
