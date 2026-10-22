import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lichess_mobile/src/model/drill/drill_history.dart';
import 'package:lichess_mobile/src/model/settings/preferences_storage.dart';

part 'drill_chart.freezed.dart';
part 'drill_chart.g.dart';

/// What the chart of the Drill History shows.
enum DrillChartMetric() {
  performance,
  rating,
  successRate,
}

/// Which Drills the chart of the Drill History shows: the last ones, or all of them.
enum DrillChartRange(
  /// How many of the last Drills are shown, or `null` for all of them.
  final int? nbDrills,
) {
  last10(10),
  last30(30),
  all(null),
}

/// What each value of the chart of the Drill History stands for.
enum DrillChartGrouping() {
  drill,
  week,
  month,
}

/// The most Drills the chart shows one by one when it shows all of them: more are grouped by week
/// or by month, so that the values don't pile up.
const kMaxDrillChartValues = 60;

/// The longest time the chart groups by week: a longer Drill History is grouped by month.
const kMaxDrillChartWeeksSpan = Duration(days: 548);

/// A value of the chart of the Drill History.
typedef DrillChartValue = ({
  /// When its Drill started, or when its week or month starts.
  DateTime date,

  /// The Drill Performance or rating, or the share of puzzles solved from 0 to 1.
  double value,

  /// Whether its Drill had enough puzzles for its performance to be reliable; always true for a
  /// week or a month.
  bool isReliable,

  /// The share of puzzles the player was expected to solve, for the share of puzzles solved.
  double? expected,
});

/// The values the chart of the Drill History draws for [metric] and [range], from the Drills'
/// [points], oldest first.
///
/// All the Drills, when more than [kMaxDrillChartValues], are grouped: by week within
/// [kMaxDrillChartWeeksSpan], else by month. A week or month gets the average performance and
/// share of puzzles solved of its Drills, and the rating after its last Drill that counted. Drills
/// without the value, such as one whose rating didn't count, are left out.
({IList<DrillChartValue> values, DrillChartGrouping grouping}) drillChartSeries(
  IList<DrillChartPoint> points, {
  required DrillChartMetric metric,
  required DrillChartRange range,
}) {
  final nbDrills = range.nbDrills;
  final shown = nbDrills != null && points.length > nbDrills
      ? points.sublist(points.length - nbDrills)
      : points;

  double? valueOf(DrillChartPoint point) => switch (metric) {
    .performance => point.performance?.toDouble(),
    .rating => point.ratingAfter?.toDouble(),
    .successRate => point.successRate,
  };

  final grouping = nbDrills != null || shown.length <= kMaxDrillChartValues
      ? DrillChartGrouping.drill
      : shown.last.startedAt.difference(shown.first.startedAt) <= kMaxDrillChartWeeksSpan
      ? DrillChartGrouping.week
      : DrillChartGrouping.month;

  if (grouping == .drill) {
    final values = [
      for (final point in shown)
        if (valueOf(point) case final value?)
          (
            date: point.startedAt,
            value: value,
            isReliable: point.isPerformanceReliable,
            expected: metric == .successRate ? point.expectedSuccessRate : null,
          ),
    ].toIList();
    return (values: values, grouping: grouping);
  }

  DateTime groupStart(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return grouping == .week
        ? day.subtract(Duration(days: day.weekday - DateTime.monday))
        : DateTime(date.year, date.month);
  }

  final groups = groupBy(shown, (point) => groupStart(point.startedAt));
  final values = [
    for (final MapEntry(key: date, value: group) in groups.entries)
      if (switch (metric) {
            .rating => group.map((p) => p.ratingAfter).nonNulls.lastOrNull?.toDouble(),
            _ => _average(group.map(valueOf).nonNulls),
          }
          case final value?)
        (
          date: date,
          value: value,
          isReliable: true,
          expected: metric == .successRate
              ? _average(group.map((p) => p.expectedSuccessRate).nonNulls)
              : null,
        ),
  ].toIList();
  return (values: values, grouping: grouping);
}

double? _average(Iterable<double> values) => values.isEmpty ? null : values.average;

/// What the chart of the Drill History shows, remembered from the last time.
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

  Future<void> setMetric(DrillChartMetric metric) => save(state.copyWith(metric: metric));

  Future<void> setRange(DrillChartRange range) => save(state.copyWith(range: range));
}

@Freezed(fromJson: true, toJson: true)
sealed class DrillChartPrefs with _$DrillChartPrefs implements Serializable {
  const factory({
    @Default(DrillChartMetric.performance) DrillChartMetric metric,
    @Default(DrillChartRange.last30) DrillChartRange range,
  }) = _DrillChartPrefs;

  factory fromJson(Map<String, dynamic> json) => _$DrillChartPrefsFromJson(json);
}
