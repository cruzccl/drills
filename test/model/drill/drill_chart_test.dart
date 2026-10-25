import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lichess_mobile/src/model/drill/drill_chart.dart';
import 'package:lichess_mobile/src/model/drill/drill_history.dart';

/// Sunday 25 October 2026, in the evening.
final _today = DateTime(2026, 10, 25, 21);

void main() {
  test('a week is its last 7 days, today included, a value per day played', () {
    // A Drill a day from 10 October, none on the 22nd
    final points = _daily(from: DateTime(2026, 10, 10), skip: {DateTime(2026, 10, 22)});

    final series = drillChartSeries(points, range: .week, today: _today);

    expect(series.grouping, DrillChartGrouping.day);
    expect(series.start, DateTime(2026, 10, 19));
    expect(series.nbSlots, 7);
    expect(series.values.map((v) => v.slot), [0, 1, 2, 4, 5, 6], reason: 'a gap on the 22nd');
    expect(series.values.first.date, DateTime(2026, 10, 19));
    expect(series.total!.nbDrills, 6);
  });

  test('a day is its Drills taken as one, each puzzle counting the same', () {
    final points = [
      _point(DateTime(2026, 10, 25, 18), nbPuzzles: 10, performance: 1500, successRate: 0.3),
      _point(DateTime(2026, 10, 25, 22), nbPuzzles: 30, performance: 1900, successRate: 0.7),
    ].toIList();

    final day = drillChartSeries(points, range: .all, today: _today).values.single;

    expect(day.nbDrills, 2);
    expect(day.nbPuzzles, 40);
    expect(day.performance, 1800, reason: '(10 × 1500 + 30 × 1900) / 40');
    expect(day.successRate, closeTo(0.6, 1e-9), reason: '24 solved out of 40');
    expect(day.expected, closeTo(0.5, 1e-9));
  });

  test('a day has no share expected when one of its Drills has none', () {
    final points = [
      _point(DateTime(2026, 10, 25, 18)),
      _point(DateTime(2026, 10, 25, 22), expected: null),
    ].toIList();

    final day = drillChartSeries(points, range: .all, today: _today).values.single;

    expect(day.expected, isNull);
    expect(day.successRate, 0.6, reason: 'still of both Drills');
  });

  test('the Drills without puzzles are left out', () {
    final points = [
      _point(DateTime(2026, 10, 24), nbPuzzles: 0, performance: null),
      _point(DateTime(2026, 10, 25)),
    ].toIList();

    final series = drillChartSeries(points, range: .all, today: _today);

    expect(series.values.map((v) => v.date), [DateTime(2026, 10, 25)]);
    expect(series.total!.nbDrills, 1);
  });

  test('the averages are of the days of the range, compared with as many days before', () {
    final points = [
      _point(DateTime(2026, 10, 11), performance: 1500),
      _point(DateTime(2026, 10, 12), performance: 1700),
      _point(DateTime(2026, 10, 18), nbPuzzles: 10, performance: 1600, successRate: 0.4),
      _point(DateTime(2026, 10, 19), nbPuzzles: 10, performance: 1800, successRate: 0.8),
      _point(DateTime(2026, 10, 25), nbPuzzles: 30, performance: 2000, successRate: 0.7),
    ].toIList();

    final week = drillChartSeries(points, range: .week, today: _today);

    // From 19 to 25 October
    expect(week.total!.nbDrills, 2);
    expect(week.total!.performance, 1950, reason: '(10 × 1800 + 30 × 2000) / 40');
    expect(week.total!.successRate, closeTo(0.725, 1e-9));
    // From 12 to 18 October
    expect(week.previous!.nbDrills, 2);
    expect(week.previous!.performance, closeTo(1666.67, 0.01));

    final year = drillChartSeries(
      _daily(from: DateTime(2025, 6, 1)),
      range: .year,
      today: _today,
    );
    expect(year.total!.nbDrills, 365, reason: 'not the days before of its first week');
    expect(year.previous!.nbDrills, 147, reason: 'from 1 June to 25 October 2025');

    expect(drillChartSeries(points, range: .all, today: _today).previous, isNull);
    final noneBefore = drillChartSeries(points.sublist(3), range: .week, today: _today);
    expect(noneBefore.previous, isNull);
  });

  test('a year is grouped by week, its first week taken whole', () {
    final points = _daily(from: DateTime(2025, 6, 1));

    final series = drillChartSeries(points, range: .year, today: _today);

    expect(series.grouping, DrillChartGrouping.week);
    // The year starts on Sunday 26 October 2025: its week from Monday 20 October
    expect(series.start, DateTime(2025, 10, 20));
    expect(series.values.first.nbDrills, 7);
    expect(series.values.last.date, DateTime(2026, 10, 19));
    expect(series.values.last.slot, series.nbSlots - 1);
  });

  test('the whole Drill History is grouped by day, week or month by how long it is', () {
    DrillChartGrouping groupingFrom(DateTime from) => drillChartSeries(
      _daily(from: from),
      range: .all,
      today: _today,
    ).grouping;

    expect(groupingFrom(DateTime(2026, 7, 27)), DrillChartGrouping.day, reason: '91 days');
    expect(groupingFrom(DateTime(2026, 7, 26)), DrillChartGrouping.week);
    expect(groupingFrom(DateTime(2025, 4, 26)), DrillChartGrouping.week, reason: '548 days');
    expect(groupingFrom(DateTime(2025, 4, 25)), DrillChartGrouping.month);

    final byMonth = drillChartSeries(
      _daily(from: DateTime(2025, 4, 25)),
      range: .all,
      today: _today,
    );
    expect(byMonth.start, DateTime(2025, 4));
    expect(byMonth.nbSlots, 19);
    expect(byMonth.values.first.nbDrills, 6, reason: 'from 25 to 30 April');
  });

  test('only the ranges the Drill History covers are offered, and all of it', () {
    IList<DrillChartRange> rangesFrom(DateTime from) =>
        drillChartRanges(_daily(from: from), today: _today);

    expect(rangesFrom(DateTime(2026, 10, 20)), [DrillChartRange.all]);
    expect(rangesFrom(DateTime(2026, 10, 19)), [DrillChartRange.week, DrillChartRange.all]);
    expect(rangesFrom(DateTime(2025, 10, 26)), DrillChartRange.values);
    expect(drillChartRanges(const IListConst([]), today: _today), [DrillChartRange.all]);
  });

  test('a range of the last Drills chosen before is the last month', () {
    expect(DrillChartPrefs.fromJson(const {'range': 'last10'}).range, DrillChartRange.month);
    expect(
      DrillChartPrefs.fromJson(const {'metric': 'successRate', 'range': 'all'}).range,
      DrillChartRange.all,
    );
  });
}

/// A Drill a day, in the evening, from [from] to [_today], except on the days of [skip].
IList<DrillChartPoint> _daily({required DateTime from, Set<DateTime> skip = const {}}) => [
  for (var day = from; !day.isAfter(_today); day = DateTime(day.year, day.month, day.day + 1))
    if (!skip.contains(day)) _point(DateTime(day.year, day.month, day.day, 20)),
].toIList();

DrillChartPoint _point(
  DateTime startedAt, {
  int nbPuzzles = 20,
  int? performance = 1600,
  double successRate = 0.6,
  double? expected = 0.5,
}) => (
  startedAt: startedAt,
  nbPuzzles: nbPuzzles,
  performance: performance,
  successRate: successRate,
  expectedSuccessRate: expected,
);
