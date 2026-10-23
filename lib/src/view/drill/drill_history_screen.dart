import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lichess_mobile/src/model/drill/drill_chart.dart';
import 'package:lichess_mobile/src/model/drill/drill_history.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_difficulty.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/view/drill/drill_angle_screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_strings.dart';
import 'package:lichess_mobile/src/view/drill/drill_summary.dart';
import 'package:lichess_mobile/src/widgets/adaptive_action_sheet.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';
import 'package:lichess_mobile/src/widgets/platform_choice_chip.dart';
import 'package:lichess_mobile/src/widgets/platform_segmented_control.dart';
import 'package:material_ui/material_ui.dart';

/// How far from the end of the list the next page of older Drills is loaded.
const _loadMoreExtent = 600.0;

/// The Drill History: the past Drills, newest first and grouped by day, under a chart of their
/// Drill Performance, rating or share of puzzles solved.
///
/// A Drill is opened on its Drill Summary, and deleted with a long press.
class const DrillHistoryScreen({super.key}) extends ConsumerWidget {
  static Route<dynamic> buildRoute() {
    return buildScreenRoute(screen: const DrillHistoryScreen());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(drillHistoryProvider);
    return PlatformScaffold(
      appBar: const PlatformAppBar(title: Text(DrillStrings.historyTitle), largeTitle: true),
      body: switch (history) {
        AsyncData(value: DrillHistoryState(:final entries)) when entries.isEmpty => const Center(
          child: Padding(padding: Styles.bodyPadding, child: Text(DrillStrings.emptyHistory)),
        ),
        AsyncData(value: DrillHistoryState(:final entries, :final hasMore)) =>
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (hasMore && notification.metrics.extentAfter < _loadMoreExtent) {
                ref.read(drillHistoryProvider.notifier).loadMore();
              }
              return false;
            },
            // The body's own context: the padding of the screen's isn't the one inside the scaffold.
            child: Builder(
              builder: (context) => ListView(
                padding: Styles.bodyPadding.add(MediaQuery.paddingOf(context)),
                children: [
                  if (entries.length > 1) ...[const _ChartCard(), const SizedBox(height: 24.0)],
                  for (final (day, dayEntries) in _groupByDay(entries)) ...[
                    _DayHeader(day, dayEntries),
                    for (final entry in dayEntries) ...[
                      _DrillCard(entry),
                      const SizedBox(height: 10.0),
                    ],
                    const SizedBox(height: 14.0),
                  ],
                  if (hasMore) const Center(child: CircularProgressIndicator.adaptive()),
                ],
              ),
            ),
          ),
        AsyncError() => const Center(child: Text('Could not load the Drill History')),
        _ => const Center(child: CircularProgressIndicator.adaptive()),
      },
    );
  }
}

/// The Drills of [entries] grouped by the day they started, in order.
List<(DateTime, List<DrillHistoryEntry>)> _groupByDay(IList<DrillHistoryEntry> entries) => [
  for (final MapEntry(key: day, value: dayEntries) in groupBy(
    entries,
    (entry) => DateUtils.dateOnly(entry.startedAt),
  ).entries)
    (day, dayEntries),
];

/// A day of the Drill History: its date, how many Drills were played and how much they changed the
/// player's rating.
class const _DayHeader(final DateTime day, final List<DrillHistoryEntry> entries)
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final changes = entries.map((e) => e.isCasual ? null : e.ratingChange).nonNulls;
    final change = changes.isEmpty ? null : changes.sum;
    final nb = entries.length;
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, right: 4.0, bottom: 10.0),
      child: Row(
        crossAxisAlignment: .baseline,
        textBaseline: .alphabetic,
        children: [
          Expanded(child: Text(drillDayName(day), style: Styles.sectionTitle)),
          Text(
            '$nb ${nb == 1 ? DrillStrings.drillUnit : DrillStrings.drillsUnit}'
            '${change != null ? ' · ' : ''}',
            style: TextStyle(fontSize: 13, color: textShade(context, Styles.subtitleOpacity)),
          ),
          if (change != null)
            Text(
              formatRatingChange(change),
              style: TextStyle(fontSize: 13, fontWeight: .bold, color: signColor(context, change)),
            ),
        ],
      ),
    );
  }
}

/// A Drill of the Drill History: what it was, its share of puzzles solved, Drill Performance and
/// rating change, then the result of each puzzle.
class const _DrillCard(final DrillHistoryEntry entry) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.lichessColors;
    final colorScheme = ColorScheme.of(context);
    final subtitleStyle = TextStyle(
      fontSize: 13,
      color: textShade(context, Styles.subtitleOpacity),
    );
    final config = entry.config;
    final ratingBefore = entry.ratingBefore?.toString() ?? '?';
    final ratingChange = entry.ratingChange;
    return Card(
      margin: .zero,
      clipBehavior: .antiAlias,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16.0))),
      child: InkWell(
        onTap: () => Navigator.of(context).push(_DrillSummaryScreen.buildRoute(entry.startedAt)),
        onLongPress: () => showConfirmDialog<void>(
          context,
          title: const Text(DrillStrings.deleteDrillConfirmation),
          isDestructiveAction: true,
          onConfirm: () => ref.read(drillHistoryProvider.notifier).delete(entry.startedAt),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14.0, 14.0, 14.0, 12.0),
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              Row(
                spacing: 6.0,
                children: [
                  Expanded(
                    child: Text(
                      drillAngleName(context, ref, config.angle),
                      style: const TextStyle(fontSize: 17, fontWeight: .w500),
                      overflow: .ellipsis,
                    ),
                  ),
                  if (entry.isPartial)
                    _Badge(DrillStrings.partial, color: colors.brag, textColor: Colors.black),
                ],
              ),
              const SizedBox(height: 4.0),
              Row(
                children: [
                  Text(DateFormat.Hm().format(entry.startedAt), style: subtitleStyle),
                  const SizedBox(width: 6.0),
                  Icon(Icons.timer_outlined, size: 14, color: subtitleStyle.color),
                  const SizedBox(width: 2.0),
                  Text(formatSolvingTime(entry.totalSolvingTime), style: subtitleStyle),
                  Flexible(
                    child: Text(
                      ' · ${puzzleDifficultyL10n(context, config.difficulty)}',
                      style: subtitleStyle,
                      overflow: .ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6.0),
                  for (final level in PuzzleDifficulty.values)
                    Container(
                      width: 6.0,
                      height: 6.0,
                      margin: const EdgeInsets.only(right: 2.0),
                      decoration: BoxDecoration(
                        shape: .circle,
                        color: level.index <= config.difficulty.index
                            ? colors.primary
                            : colorScheme.outlineVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12.0),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: .stretch,
                  spacing: 8.0,
                  children: [
                    _MetricTile(
                      label: DrillStrings.successes,
                      value: '${(entry.successRate * 100).round()} %',
                      valueColor: successRateColor(
                        context,
                        entry.successRate,
                        entry.expectedSuccessRate,
                      ),
                      details: [
                        [
                          '${entry.successes} / ${entry.nbPlayed}',
                          if (entry.isPartial) '${DrillStrings.ofTotal} ${config.nbPuzzles}',
                        ].join(' · '),
                      ],
                    ),
                    _MetricTile(
                      label: DrillStrings.performance,
                      value: entry.performance?.toString() ?? '-',
                      valueColor: colors.primary,
                      opacity: entry.isPerformanceReliable ? 1.0 : 0.55,
                      details: [if (!entry.isPerformanceReliable) DrillStrings.unreliable],
                    ),
                    _MetricTile(
                      label: DrillStrings.points,
                      value: entry.isCasual
                          ? '—'
                          : ratingChange == null
                          ? '···'
                          : formatRatingChange(ratingChange),
                      valueColor: entry.isCasual || ratingChange == null
                          ? textShade(context, Styles.subtitleOpacity)
                          : signColor(context, ratingChange),
                      opacity: entry.isCasual ? 0.55 : 1.0,
                      detail: entry.isCasual
                          ? Text(ratingBefore)
                          : Row(
                              mainAxisSize: .min,
                              spacing: 3.0,
                              children: [
                                Text(ratingBefore),
                                const Icon(Icons.arrow_forward, size: 12),
                                Text(entry.ratingAfter?.toString() ?? '?'),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12.0),
              Row(
                spacing: 3.0,
                children: [
                  for (var i = 0; i < config.nbPuzzles; i++)
                    Expanded(
                      child: Container(
                        height: 6.0,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.all(Radius.circular(3.0)),
                          color: i >= entry.nbPlayed
                              ? colorScheme.outlineVariant
                              : entry.wins[i]
                              ? colors.good
                              : colors.error,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the three figures of a [_DrillCard]: its label, value and details, centered.
class const _MetricTile({
  required final String label,
  required final String value,
  final Color? valueColor,
  final double opacity = 1.0,
  final List<String> details = const [],
  final Widget? detail,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final detailStyle = TextStyle(fontSize: 12, color: textShade(context, Styles.subtitleOpacity));
    return Expanded(
      child: Opacity(
        opacity: opacity,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
          decoration: BoxDecoration(
            color: ColorScheme.of(context).surfaceContainerLowest,
            borderRadius: const BorderRadius.all(Radius.circular(10.0)),
          ),
          child: Column(
            mainAxisAlignment: .center,
            spacing: 2.0,
            children: [
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: .ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.3,
                  color: textShade(context, Styles.subtitleOpacity),
                ),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 22, fontWeight: .bold, color: valueColor),
              ),
              for (final text in details) Text(text, textAlign: .center, style: detailStyle),
              if (detail != null) DefaultTextStyle.merge(style: detailStyle, child: detail!),
            ],
          ),
        ),
      ),
    );
  }
}

class const _Badge(final String text, {required final Color color, required final Color textColor})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.all(Radius.circular(10.0)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: .bold, color: textColor),
      ),
    );
  }
}

/// The Drill Summary of a past Drill, with its rating changes as they come.
class const _DrillSummaryScreen(final DateTime startedAt) extends ConsumerWidget {
  static Route<dynamic> buildRoute(DateTime startedAt) {
    return buildScreenRoute(screen: _DrillSummaryScreen(startedAt));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drill = ref.watch(drillHistoryDrillProvider(startedAt));
    return PlatformScaffold(
      appBar: const PlatformAppBar(title: Text(DrillStrings.summaryTitle)),
      body: switch (drill) {
        AsyncValue(value: final drill?) => DrillSummary(drill),
        AsyncData() || AsyncError() => const Center(child: Text('Could not load the Drill')),
        _ => const Center(child: CircularProgressIndicator.adaptive()),
      },
    );
  }
}

/// The chart of the Drill History, of the Drill Performance, rating or share of puzzles solved of
/// the last Drills or all of them, as chosen.
class const _ChartCard() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(drillChartPreferencesProvider);
    final prefsCtrl = ref.read(drillChartPreferencesProvider.notifier);
    final points = ref.watch(drillChartPointsProvider).value ?? const IListConst([]);
    final (:values, :grouping) = drillChartSeries(points, metric: prefs.metric, range: prefs.range);
    final nbDrills = prefs.range.nbDrills;
    final nbShown = nbDrills != null && points.length > nbDrills ? nbDrills : points.length;
    final subtitleStyle = TextStyle(
      fontSize: 12,
      color: textShade(context, Styles.subtitleOpacity),
    );
    final caption = [
      if (prefs.range == .all)
        '${DrillStrings.allDrillsCount} (${points.length})${switch (grouping) {
          .week => ', ${DrillStrings.byWeek}',
          .month => ', ${DrillStrings.byMonth}',
          .drill => '',
        }}'
      else
        '${DrillStrings.lastDrills} $nbShown ${DrillStrings.drillsUnit}',
      if (prefs.metric == .rating) DrillStrings.afterRatedDrills,
    ].join(' · ');

    return Card(
      margin: .zero,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16.0))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            PlatformSegmentedControl<DrillChartMetric>(
              segments: const [
                (DrillChartMetric.performance, DrillStrings.performance),
                (DrillChartMetric.rating, DrillStrings.rating),
                (DrillChartMetric.successRate, DrillStrings.successes),
              ],
              selected: prefs.metric,
              onChanged: prefsCtrl.setMetric,
              showSelectedIcon: false,
              expandedInsets: EdgeInsets.zero,
            ),
            const SizedBox(height: 12.0),
            Row(
              children: [
                Expanded(
                  child: _ChartHeadline(values, metric: prefs.metric, grouping: grouping),
                ),
                Wrap(
                  spacing: 4.0,
                  children: [
                    for (final (range, label) in const [
                      (DrillChartRange.last10, '10'),
                      (DrillChartRange.last30, '30'),
                      (DrillChartRange.all, DrillStrings.allDrills),
                    ])
                      PlatformChoiceChip(
                        label: Text(label),
                        selected: prefs.range == range,
                        showCheckmark: false,
                        onSelected: (_) => prefsCtrl.setRange(range),
                      ),
                  ],
                ),
              ],
            ),
            Text(caption, style: subtitleStyle),
            const SizedBox(height: 12.0),
            SizedBox(
              height: 120.0,
              child: values.isEmpty
                  ? Center(child: Text(DrillStrings.noChartData, style: subtitleStyle))
                  : prefs.metric == .successRate
                  ? _SuccessRateChart(values)
                  : _LineChart(values, metric: prefs.metric),
            ),
            if (values.isNotEmpty) ...[
              const SizedBox(height: 6.0),
              Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  Text(drillDayName(values.first.date, short: true), style: subtitleStyle),
                  Text(drillDayName(values.last.date, short: true), style: subtitleStyle),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The last value of the chart and how it compares with the previous one, or for the share of
/// puzzles solved, with the average.
class const _ChartHeadline(
  final IList<DrillChartValue> values, {
  required final DrillChartMetric metric,
  required final DrillChartGrouping grouping,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final last = values.lastOrNull;
    if (last == null) return const SizedBox.shrink();
    final String value;
    final Color? valueColor;
    final String comparison;
    final Color? comparisonColor;
    if (metric == .successRate) {
      final average = values.map((v) => v.value).average;
      value = '${(last.value * 100).round()} %';
      valueColor = successRateColor(context, last.value, last.expected);
      comparison = '${DrillStrings.average} ${(average * 100).round()} %';
      comparisonColor = textShade(context, Styles.subtitleOpacity);
    } else {
      value = '${last.value.round()}';
      valueColor = null;
      final previous = values.length > 1 ? values[values.length - 2] : null;
      final change = previous != null ? last.value.round() - previous.value.round() : null;
      final since = switch (grouping) {
        .drill => DrillStrings.sinceLastDrill,
        .week => DrillStrings.sinceLastWeek,
        .month => DrillStrings.sinceLastMonth,
      };
      comparison = change == null ? '' : '${formatRatingChange(change)} $since';
      comparisonColor = change != null ? signColor(context, change) : null;
    }
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

/// The chart of the Drill Performance or the rating: a line through the values, the performances
/// of the Drills too short to be reliable hollow.
class const _LineChart(
  final IList<DrillChartValue> values, {
  required final DrillChartMetric metric,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.lichessColors;
    final color = metric == .performance ? colors.primary : colors.purple;
    final cardColor =
        Theme.of(context).cardTheme.color ?? ColorScheme.of(context).surfaceContainerLow;
    final gridColor = ColorScheme.of(context).outlineVariant;
    final lowest = values.map((v) => v.value).min;
    final highest = values.map((v) => v.value).max;
    final minY = ((lowest - 20) / 50).floorToDouble() * 50;
    final maxY = ((highest + 20) / 50).ceilToDouble() * 50;
    final dotRadius = values.length > 20 ? 2.5 : 4.0;
    return LineChart(
      LineChartData(
        minX: values.length == 1 ? -0.5 : 0,
        maxX: values.length == 1 ? 0.5 : values.length - 1.0,
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: [for (final (i, v) in values.indexed) FlSpot(i.toDouble(), v.value)],
            color: color,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              getDotPainter: (spot, _, _, index) => FlDotCirclePainter(
                radius: dotRadius,
                color: values[index].isReliable ? color : cardColor,
                strokeColor: color,
                strokeWidth: 2,
              ),
            ),
          ),
        ],
        borderData: FlBorderData(
          show: true,
          border: Border(bottom: BorderSide(color: gridColor)),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 2,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: gridColor, strokeWidth: 0.5, dashArray: const [3, 4]),
        ),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => ColorScheme.of(context).inverseSurface,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) => [
              for (final spot in spots)
                LineTooltipItem(
                  '${spot.y.round()}\n',
                  _tooltipStyle(context),
                  children: [_tooltipDate(context, values[spot.x.toInt()].date)],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The chart of the share of puzzles solved: a bar per value, colored by how it compares with the
/// share expected.
class const _SuccessRateChart(final IList<DrillChartValue> values) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final gridColor = ColorScheme.of(context).outlineVariant;
    return LayoutBuilder(
      builder: (context, constraints) {
        final slot = constraints.maxWidth / values.length;
        final barWidth = (slot - (values.length > 20 ? 2 : 4)).clamp(1.0, 24.0);
        return BarChart(
          BarChartData(
            minY: 0,
            maxY: 100,
            alignment: .spaceAround,
            barGroups: [
              for (final (i, v) in values.indexed)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: v.value * 100,
                      width: barWidth,
                      color:
                          successRateColor(context, v.value, v.expected) ??
                          ColorScheme.of(context).onSurface,
                      borderRadius: BorderRadius.all(Radius.circular(barWidth > 6 ? 3.0 : 1.0)),
                    ),
                  ],
                ),
            ],
            borderData: FlBorderData(
              show: true,
              border: Border(bottom: BorderSide(color: gridColor)),
            ),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: 50,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: gridColor, strokeWidth: 0.5, dashArray: const [3, 4]),
            ),
            titlesData: const FlTitlesData(show: false),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => ColorScheme.of(context).inverseSurface,
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                  '${rod.toY.round()} %\n',
                  _tooltipStyle(context),
                  children: [_tooltipDate(context, values[group.x].date)],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

TextStyle _tooltipStyle(BuildContext context) =>
    TextStyle(fontWeight: .bold, color: ColorScheme.of(context).onInverseSurface);

TextSpan _tooltipDate(BuildContext context, DateTime date) => TextSpan(
  text: drillDayName(date, short: true),
  style: TextStyle(
    fontSize: 11,
    fontWeight: .normal,
    color: ColorScheme.of(context).onInverseSurface,
  ),
);

/// The name of the day of [date]: today, yesterday, or its date, with the year if it is not this
/// year's, and with the day of the week unless [short].
String drillDayName(DateTime date, {bool short = false}) {
  final today = DateUtils.dateOnly(DateTime.now());
  final day = DateUtils.dateOnly(date);
  if (day == today) return DrillStrings.today;
  if (day == today.subtract(const Duration(days: 1))) return DrillStrings.yesterday;
  final format = day.year == today.year
      ? (short ? DateFormat.MMMd() : DateFormat.MMMEd())
      : (short ? DateFormat.yMMMd() : DateFormat.yMMMEd());
  final name = format.format(date);
  return name.isEmpty ? name : name[0].toUpperCase() + name.substring(1);
}
