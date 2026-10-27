import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lichess_mobile/src/model/drill/drill_chart.dart';
import 'package:lichess_mobile/src/model/drill/drill_history.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/view/drill/drill_history_screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_summary.dart';
import 'package:lichess_mobile/src/view/user/perf_stats_screen.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';
import 'package:material_ui/material_ui.dart';

/// The longest range whose calendar shows each day with its number: a longer one is a heatmap of
/// small squares, a column per week.
const _maxNumberedCalendarDays = 31;

/// The player's progress over the days of a range, opened from the streak of the Drill home: their
/// streaks of days in a row with a Drill and the calendar of the days played, then the charts of
/// their Drill Performance and share of puzzles solved.
class const DrillProgressScreen({super.key}) extends ConsumerWidget {
  static Route<void> buildRoute() => buildScreenRoute(screen: const DrillProgressScreen());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = ref.watch(drillChartPointsProvider).value ?? const IListConst([]);
    final today = DateTime.now();
    final ranges = drillChartRanges(points, today: today);
    final chosen = ref.watch(drillChartPreferencesProvider.select((prefs) => prefs.range));
    // A range longer than the Drill History isn't offered: the whole of it is shown instead.
    final range = ranges.contains(chosen) ? chosen : DrillChartRange.all;
    final series = drillChartSeries(points, range: range, today: today);
    final total = series.total;
    return PlatformScaffold(
      appBar: PlatformAppBar(title: Text(context.drillL10n.progress)),
      // The body's own context: the padding of the screen's isn't the one inside the scaffold.
      body: Builder(
        builder: (context) => ListView(
          padding: Styles.bodyPadding.add(MediaQuery.paddingOf(context)),
          children: [
            Row(
              mainAxisAlignment: .spaceEvenly,
              children: [
                for (final choice in ranges)
                  ChartRangeButton(
                    text: switch (choice) {
                      .week => context.drillL10n.rangeWeek,
                      .month => context.drillL10n.rangeMonth,
                      .threeMonths => context.drillL10n.rangeThreeMonths,
                      .year => context.drillL10n.rangeYear,
                      .all => context.drillL10n.allDays,
                    },
                    selected: choice == range,
                    onPressed: () =>
                        ref.read(drillChartPreferencesProvider.notifier).setRange(choice),
                  ),
              ],
            ),
            if (total != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0, left: 4.0, right: 4.0),
                child: Text(
                  '${context.drillL10n.nbDrills(total.nbDrills)}, '
                  '${context.drillL10n.nbPuzzles(total.nbPuzzles)} · '
                  '${switch (series.grouping) {
                    .day => context.drillL10n.byDay,
                    .week => context.drillL10n.byWeek,
                    .month => context.drillL10n.byMonth,
                  }}',
                  style: TextStyle(fontSize: 12, color: textShade(context, Styles.subtitleOpacity)),
                ),
              ),
            const SizedBox(height: 16.0),
            _StreakCard(points: points, range: range, today: today),
            const SizedBox(height: 16.0),
            _ChartCard(series: series, range: range),
          ],
        ),
      ),
    );
  }
}

/// The streaks of days in a row with a Drill, the number of days played in the range, and their
/// calendar.
class const _StreakCard({
  required final IList<DrillChartPoint> points,
  required final DrillChartRange range,
  required final DateTime today,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final streak = drillStreak(points, today: today);
    final byDay = drillPuzzlesByDay(points);
    final start = drillChartRangeStart(points, range: range, today: today);
    final lastDay = DateUtils.dateOnly(today);
    final nbDays = _daysBetween(start, lastDay) + 1;
    final nbPlayed = byDay.keys
        .where((day) => !day.isBefore(start) && !day.isAfter(lastDay))
        .length;
    final labelStyle = TextStyle(fontSize: 12, color: textShade(context, Styles.subtitleOpacity));
    const valueStyle = TextStyle(fontSize: 26, fontWeight: .bold);
    return Card(
      margin: .zero,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16.0))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: .stretch,
          spacing: 12.0,
          children: [
            Text(context.drillL10n.streak, style: const TextStyle(fontSize: 14, fontWeight: .w600)),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        '${streak.current}',
                        style: valueStyle.copyWith(color: context.lichessColors.brag),
                      ),
                      Text(context.drillL10n.daysInARow(streak.current), style: labelStyle),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text('${streak.best}', style: valueStyle),
                      Text(context.drillL10n.bestStreakLabel, style: labelStyle),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text.rich(
                        TextSpan(
                          text: '$nbPlayed',
                          children: [
                            TextSpan(
                              text: ' / $nbDays',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: .normal,
                                color: labelStyle.color,
                              ),
                            ),
                          ],
                        ),
                        style: valueStyle,
                      ),
                      Text(context.drillL10n.daysWithDrills, style: labelStyle),
                    ],
                  ),
                ),
              ],
            ),
            if (nbDays <= _maxNumberedCalendarDays)
              _NumberedCalendar(byDay: byDay, start: start, today: lastDay)
            else
              _HeatmapCalendar(byDay: byDay, start: start, today: lastDay),
            Row(
              mainAxisAlignment: .end,
              spacing: 4.0,
              children: [
                Text(context.drillL10n.fewerPuzzles, style: labelStyle.copyWith(fontSize: 10)),
                for (var level = 0; level <= 3; level++)
                  Container(
                    width: 10.0,
                    height: 10.0,
                    decoration: BoxDecoration(
                      color: _levelColor(context, level),
                      borderRadius: const BorderRadius.all(Radius.circular(3.0)),
                    ),
                  ),
                Text(context.drillL10n.morePuzzles, style: labelStyle.copyWith(fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The calendar of a short range, a row per week from Monday: each day of the range with its
/// number, colored by the number of puzzles played, today ringed.
class const _NumberedCalendar({
  required final IMap<DateTime, int> byDay,
  required final DateTime start,
  required final DateTime today,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final first = _addDays(start, -(start.weekday - DateTime.monday));
    final nbWeeks = (_daysBetween(first, today) ~/ 7) + 1;
    final weekdayFormat = DateFormat('EEEEE');
    final labelStyle = TextStyle(fontSize: 10, color: textShade(context, Styles.subtitleOpacity));
    final onSurface = ColorScheme.of(context).onSurface;
    return Column(
      spacing: 5.0,
      children: [
        Row(
          spacing: 5.0,
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Text(
                  weekdayFormat.format(_addDays(first, i)).toUpperCase(),
                  textAlign: .center,
                  style: labelStyle,
                ),
              ),
          ],
        ),
        for (var week = 0; week < nbWeeks; week++)
          Row(
            spacing: 5.0,
            children: [
              for (var i = 0; i < 7; i++)
                if (_addDays(first, week * 7 + i) case final day)
                  Expanded(
                    child: day.isBefore(start) || day.isAfter(today)
                        ? const SizedBox(height: 36.0)
                        : Container(
                            height: 36.0,
                            alignment: .center,
                            decoration: BoxDecoration(
                              color: _levelColor(context, _level(byDay[day] ?? 0)),
                              borderRadius: const BorderRadius.all(Radius.circular(8.0)),
                              border: day == today
                                  ? Border.all(color: onSurface, width: 1.5)
                                  : null,
                            ),
                            child: Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 11,
                                color: _level(byDay[day] ?? 0) == 3
                                    ? Colors.black
                                    : textShade(context, 0.8),
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

/// The calendar of a long range: a column of 7 small squares per week, from Monday, colored by
/// the number of puzzles played.
class const _HeatmapCalendar({
  required final IMap<DateTime, int> byDay,
  required final DateTime start,
  required final DateTime today,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final first = _addDays(start, -(start.weekday - DateTime.monday));
    final nbWeeks = (_daysBetween(first, today) ~/ 7) + 1;
    Color? colorOf(DateTime day) => day.isBefore(start) || day.isAfter(today)
        ? null
        : _levelColor(context, _level(byDay[day] ?? 0));
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = constraints.maxWidth / nbWeeks > 6.0 ? 2.0 : 1.0;
        final cell = math.min(14.0, (constraints.maxWidth - gap * (nbWeeks - 1)) / nbWeeks);
        return SizedBox(
          height: cell * 7 + gap * 6,
          child: CustomPaint(
            size: Size(constraints.maxWidth, cell * 7 + gap * 6),
            painter: _HeatmapPainter(
              colors: [for (var i = 0; i < nbWeeks * 7; i++) colorOf(_addDays(first, i))],
              cell: cell,
              gap: gap,
            ),
          ),
        );
      },
    );
  }
}

class _HeatmapPainter({
  /// The color of each day, a week after the other, `null` for those out of the range.
  required final List<Color?> colors,
  required final double cell,
  required final double gap,
}) extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final radius = Radius.circular(cell / 4);
    for (var i = 0; i < colors.length; i++) {
      final color = colors[i];
      if (color == null) continue;
      paint.color = color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH((i ~/ 7) * (cell + gap), (i % 7) * (cell + gap), cell, cell),
          radius,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter oldDelegate) =>
      !const ListEquality<Color?>().equals(colors, oldDelegate.colors) ||
      cell != oldDelegate.cell ||
      gap != oldDelegate.gap;
}

/// How many puzzles were played on a day, from 0 (none) to 3 (more than 20).
int _level(int nbPuzzles) => switch (nbPuzzles) {
  0 => 0,
  <= 10 => 1,
  <= 20 => 2,
  _ => 3,
};

Color _levelColor(BuildContext context, int level) => switch (level) {
  0 => ColorScheme.of(context).onSurface.withValues(alpha: 0.08),
  1 => context.lichessColors.brag.withValues(alpha: 0.35),
  2 => context.lichessColors.brag.withValues(alpha: 0.65),
  _ => context.lichessColors.brag,
};

DateTime _addDays(DateTime day, int nbDays) => DateTime(day.year, day.month, day.day + nbDays);

/// The number of days from [from] to [to], whatever the daylight saving time changes between.
int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// The width kept left of the charts for the values of their axis, the same for both so that
/// their days line up.
const _axisWidth = 36.0;

/// The charts of the Drill History over the days of a range, as the puzzle rating history of the
/// profile: the Drill Performance above, the share of puzzles solved below, by day, week or month.
class const _ChartCard({
  required final DrillChartSeries series,
  required final DrillChartRange range,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final subtitleStyle = TextStyle(
      fontSize: 12,
      color: textShade(context, Styles.subtitleOpacity),
    );
    const titleStyle = TextStyle(fontSize: 14, fontWeight: .w600);

    return Card(
      margin: .zero,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16.0))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: series.total == null
            ? SizedBox(
                height: 120.0,
                child: Center(child: Text(context.drillL10n.noChartData, style: subtitleStyle)),
              )
            : Column(
                crossAxisAlignment: .stretch,
                children: [
                  Text(context.drillL10n.performance, style: titleStyle),
                  _PerformanceHeadline(series, range: range),
                  const SizedBox(height: 8.0),
                  SizedBox(height: 150.0, child: _PerformanceChart(series)),
                  _DateAxis(series),
                  const SizedBox(height: 16.0),
                  Text(context.drillL10n.successes, style: titleStyle),
                  _SuccessRateHeadline(series),
                  const SizedBox(height: 8.0),
                  SizedBox(height: 110.0, child: _SuccessRateChart(series)),
                  _DateAxis(series),
                  const SizedBox(height: 8.0),
                  Wrap(
                    spacing: 16.0,
                    runSpacing: 4.0,
                    children: [
                      for (final (color, label) in [
                        (context.lichessColors.good, context.drillL10n.aboveExpected),
                        (ColorScheme.of(context).onSurface, context.drillL10n.withinExpected),
                        (context.lichessColors.error, context.drillL10n.belowExpected),
                      ])
                        Row(
                          mainAxisSize: .min,
                          spacing: 6.0,
                          children: [
                            SizedBox.square(
                              dimension: 10.0,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: const BorderRadius.all(Radius.circular(2.0)),
                                ),
                              ),
                            ),
                            Text(label, style: subtitleStyle),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

/// The Drill Performance of the days of the range, and its change on as many days before.
class const _PerformanceHeadline(
  final DrillChartSeries series, {
  required final DrillChartRange range,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final performance = series.total!.performance.round();
    final change = switch (series.previous) {
      final previous? => performance - previous.performance.round(),
      null => null,
    };
    final l10n = context.drillL10n;
    final comparison = switch (change) {
      null => '',
      final change => switch (range) {
        .week => l10n.changeSinceLastWeek,
        .month => l10n.changeSinceLastMonth,
        .threeMonths => l10n.changeSinceLastThreeMonths,
        .year => l10n.changeSinceLastYear,
        .all => (String change) => change,
      }(formatRatingChange(change)),
    };
    return _ChartHeadline(
      value: '$performance',
      comparison: comparison,
      comparisonColor: change != null ? signColor(context, change) : null,
    );
  }
}

/// The share of puzzles solved of the days of the range, colored by how it compares with the
/// share expected, next to it.
class const _SuccessRateHeadline(final DrillChartSeries series) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final total = series.total!;
    return _ChartHeadline(
      value: '${_percent(total.successRate)} %',
      valueColor: successRateColor(context, total.successRate, total.expected),
      comparison: switch (total.expected) {
        final expected? => context.drillL10n.expectedPercent(_percent(expected)),
        null => '',
      },
      comparisonColor: textShade(context, Styles.subtitleOpacity),
    );
  }
}

int _percent(double share) => (share * 100).round();

class const _ChartHeadline({
  required final String value,
  final Color? valueColor,
  required final String comparison,
  final Color? comparisonColor,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: TextStyle(fontSize: 28, fontWeight: .bold, color: valueColor),
          ),
          if (comparison.isNotEmpty)
            TextSpan(
              text: '  $comparison',
              style: TextStyle(fontSize: 14, fontWeight: .w500, color: comparisonColor),
            ),
        ],
      ),
    );
  }
}

/// The chart of the Drill Performance, as the puzzle rating history of the profile: a line
/// through the days, weeks or months played, each in the middle of its place on the chart.
class const _PerformanceChart(final DrillChartSeries series) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final values = series.values;
    final color = Styles.chartColor(context);
    final borderColor = ColorScheme.of(context).onSurface.withValues(alpha: 0.5);
    final lowest = values.map((v) => v.performance).min;
    final highest = values.map((v) => v.performance).max;
    final step = highest - lowest > 300 ? 100.0 : 50.0;
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: series.nbSlots.toDouble(),
        minY: ((lowest - 10) / step).floorToDouble() * step,
        maxY: ((highest + 10) / step).ceilToDouble() * step,
        lineBarsData: [
          LineChartBarData(
            spots: [for (final v in values) FlSpot(v.slot + 0.5, v.performance)],
            color: color,
            barWidth: 1.5,
            dotData: FlDotData(show: values.length == 1),
            belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.3)),
          ),
        ],
        borderData: _chartBorder(borderColor),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: step,
          getDrawingHorizontalLine: (_) => FlLine(color: borderColor, strokeWidth: 0.5),
        ),
        titlesData: _chartTitles(context, interval: step, label: (y) => '${y.round()}'),
        lineTouchData: LineTouchData(
          touchSpotThreshold: double.infinity,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => ColorScheme.of(context).inverseSurface,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) => [
              for (final spot in spots)
                if (values[spot.spotIndex] case final value)
                  LineTooltipItem(
                    '${value.performance.round()}\n',
                    _tooltipStyle(context),
                    children: [
                      _tooltipDetail(
                        context,
                        '${_valueName(context, value, series.grouping)}\n'
                        '${context.drillL10n.nbDrills(value.nbDrills)}, '
                        '${context.drillL10n.nbPuzzles(value.nbPuzzles)}',
                      ),
                    ],
                  ),
            ],
          ),
          getTouchedSpotIndicator: (_, indexes) => [
            for (final _ in indexes)
              TouchedSpotIndicatorData(
                FlLine(color: color, strokeWidth: 2),
                FlDotData(
                  getDotPainter: (_, _, _, _) => FlDotCirclePainter(radius: 5, color: color),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The chart of the share of puzzles solved: a bar per day, week or month played, colored by how
/// it compares with the share expected, under the days of the chart above.
class const _SuccessRateChart(final DrillChartSeries series) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bySlot = {for (final v in series.values) v.slot: v};
    final borderColor = ColorScheme.of(context).onSurface.withValues(alpha: 0.5);
    return LayoutBuilder(
      builder: (context, constraints) {
        final slotWidth = (constraints.maxWidth - _axisWidth) / series.nbSlots;
        final barWidth = (slotWidth * 0.7).clamp(1.0, 18.0);
        return BarChart(
          BarChartData(
            minY: 0,
            maxY: 100,
            alignment: .spaceAround,
            // A group per day, week or month of the chart, oldest first, all as wide: those not
            // played leave a gap, and the others are below their value in the chart above.
            barGroups: [
              for (var slot = 0; slot < series.nbSlots; slot++)
                BarChartGroupData(
                  x: slot,
                  barRods: [
                    BarChartRodData(
                      toY: (bySlot[slot]?.successRate ?? 0) * 100,
                      width: barWidth,
                      color: switch (bySlot[slot]) {
                        final v? =>
                          successRateColor(context, v.successRate, v.expected) ??
                              ColorScheme.of(context).onSurface,
                        null => Colors.transparent,
                      },
                      borderRadius: BorderRadius.all(Radius.circular(barWidth > 6 ? 3.0 : 1.0)),
                    ),
                  ],
                ),
            ],
            borderData: _chartBorder(borderColor),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: 25,
              getDrawingHorizontalLine: (_) => FlLine(color: borderColor, strokeWidth: 0.5),
            ),
            titlesData: _chartTitles(context, interval: 25, label: (y) => '${y.round()} %'),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => ColorScheme.of(context).inverseSurface,
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItem: (group, _, _, _) {
                  final value = bySlot[group.x];
                  if (value == null) return null;
                  final solved = (value.successRate * value.nbPuzzles).round();
                  return BarTooltipItem(
                    '${_percent(value.successRate)} %\n',
                    _tooltipStyle(context),
                    children: [
                      _tooltipDetail(
                        context,
                        '${_valueName(context, value, series.grouping)}\n'
                        '${switch (value.expected) {
                          final expected? => context.drillL10n.nbOfTotalExpectedPercent(solved, value.nbPuzzles, _percent(expected)),
                          null => context.drillL10n.nbOfTotal(solved, value.nbPuzzles),
                        }}',
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

FlBorderData _chartBorder(Color color) => FlBorderData(
  show: true,
  border: Border(
    bottom: BorderSide(color: color),
    left: BorderSide(color: color),
  ),
);

/// The values of the vertical axis on the left, in [_axisWidth], every [interval].
FlTitlesData _chartTitles(
  BuildContext context, {
  required double interval,
  required String Function(double y) label,
}) => FlTitlesData(
  topTitles: const AxisTitles(),
  rightTitles: const AxisTitles(),
  bottomTitles: const AxisTitles(),
  leftTitles: AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: _axisWidth,
      interval: interval,
      getTitlesWidget: (y, meta) => SideTitleWidget(
        meta: meta,
        child: Text(label(y), style: TextStyle(color: textShade(context, 0.6), fontSize: 10)),
      ),
    ),
  ),
);

/// The dates below a chart, a third and two thirds of the way along it.
class const _DateAxis(final DrillChartSeries series) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final start = series.start;
    final format = series.grouping == .day && series.nbSlots <= 31
        ? DateFormat.MMMd()
        : DateFormat.yMMM();
    final style = TextStyle(color: textShade(context, 0.6), fontSize: 10);
    return SizedBox(
      height: 18.0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth - _axisWidth;
          return Stack(
            children: [
              for (final third in [1, 2])
                if ((series.nbSlots * third / 3).floor() case final slot)
                  Positioned(
                    left: _axisWidth + width * third / 3 - 40.0,
                    width: 80.0,
                    bottom: 0,
                    child: Text(
                      format.format(switch (series.grouping) {
                        .day => DateTime(start.year, start.month, start.day + slot),
                        .week => DateTime(start.year, start.month, start.day + 7 * slot),
                        .month => DateTime(start.year, start.month + slot),
                      }),
                      textAlign: .center,
                      style: style,
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

/// The name of the day, week or month of [value].
String _valueName(BuildContext context, DrillChartValue value, DrillChartGrouping grouping) =>
    switch (grouping) {
      .day => drillDayName(context, value.date, short: true),
      .week => context.drillL10n.weekOf(
        (value.date.year == DateTime.now().year ? DateFormat.MMMd() : DateFormat.yMMMd()).format(
          value.date,
        ),
      ),
      .month => () {
        final name = DateFormat.yMMMM().format(value.date);
        return name.isEmpty ? name : name[0].toUpperCase() + name.substring(1);
      }(),
    };

TextStyle _tooltipStyle(BuildContext context) =>
    TextStyle(fontWeight: .bold, color: ColorScheme.of(context).onInverseSurface);

TextSpan _tooltipDetail(BuildContext context, String text) => TextSpan(
  text: text,
  style: TextStyle(
    fontSize: 11,
    fontWeight: .normal,
    color: ColorScheme.of(context).onInverseSurface,
  ),
);
