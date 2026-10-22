import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lichess_mobile/src/model/drill/drill_chart.dart';
import 'package:lichess_mobile/src/model/drill/drill_history.dart';

void main() {
  test('the last Drills are shown one by one', () {
    final points = _daily(40);

    final (:values, :grouping) = drillChartSeries(points, metric: .performance, range: .last10);

    expect(grouping, DrillChartGrouping.drill);
    expect(values.map((v) => v.value), [for (var i = 30; i < 40; i++) 1400.0 + i]);
    expect(values.first.date, DateTime(2026, 1, 31));
  });

  test('all the Drills are shown one by one while they are few', () {
    final (:values, :grouping) = drillChartSeries(_daily(60), metric: .performance, range: .all);

    expect(grouping, DrillChartGrouping.drill);
    expect(values, hasLength(60));
  });

  test('all the Drills are grouped by week, then by month over a long time', () {
    // Monday 5 January 2026, then a Drill a day: 3 weeks of 7 and 4 more
    final (:values, :grouping) = drillChartSeries(
      _daily(61, from: DateTime(2026, 1, 5)),
      metric: .performance,
      range: .all,
    );

    expect(grouping, DrillChartGrouping.week);
    expect(values, hasLength(9));
    expect(values.first.date, DateTime(2026, 1, 5));
    expect(values.first.value, 1403, reason: 'the average of its 7 Drills');
    expect(values.last.date, DateTime(2026, 3, 2));
    expect(values.last.value, 1458, reason: 'its 5 Drills, from Monday to Friday');

    final longTime = _daily(61, every: const Duration(days: 10));
    final byMonth = drillChartSeries(longTime, metric: .performance, range: .all);
    expect(byMonth.grouping, DrillChartGrouping.month);
    expect(byMonth.values.first.date, DateTime(2026));
    expect(byMonth.values.first.value, 1401.5, reason: 'the 1st, 11th, 21st and 31st January');
  });

  test("the rating chart leaves out the Drills that didn't count", () {
    final points = _daily(5, ratingAfter: (i) => i.isEven ? 1500 + i : null);

    final perDrill = drillChartSeries(points, metric: .rating, range: .last10);
    expect(perDrill.values.map((v) => v.value), [1500, 1502, 1504]);

    final byWeek = drillChartSeries(
      _daily(70, ratingAfter: (i) => i % 7 == 3 ? null : 1500 + i),
      metric: .rating,
      range: .all,
    );
    expect(byWeek.grouping, DrillChartGrouping.week);
    // Thursday 1 January to Sunday 4 January, whose Drill didn't count
    expect(byWeek.values.first.date, DateTime(2025, 12, 29));
    expect(byWeek.values.first.value, 1502, reason: 'after its last Drill that counted');
    expect(byWeek.values[1].value, 1509, reason: 'the 10th, Sunday 11th not counting');
  });

  test('the share of puzzles solved comes with the share expected', () {
    final points = _daily(3, expected: (i) => i == 1 ? null : 0.5);

    final (:values, grouping: _) = drillChartSeries(points, metric: .successRate, range: .last30);

    expect(values.map((v) => v.value), [0.6, 0.6, 0.6]);
    expect(values.map((v) => v.expected), [0.5, null, 0.5]);
  });
}

/// [nb] Drills, one every [every] from [from]: the i-th at 1400 + i performance, with 60 % of its
/// puzzles solved.
IList<DrillChartPoint> _daily(
  int nb, {
  DateTime? from,
  Duration every = const Duration(days: 1),
  int? Function(int i)? ratingAfter,
  double? Function(int i)? expected,
}) => [
  for (var i = 0; i < nb; i++)
    (
      startedAt: (from ?? DateTime(2026)).add(every * i),
      performance: 1400 + i,
      isPerformanceReliable: true,
      successRate: 0.6,
      expectedSuccessRate: expected != null ? expected(i) : 0.5,
      ratingAfter: ratingAfter != null ? ratingAfter(i) : 1500,
    ),
].toIList();
