import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lichess_mobile/src/model/drill/drill_chart.dart';
import 'package:lichess_mobile/src/model/drill/drill_history.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_angle.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_difficulty.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/view/drill/drill_angle_screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_strings.dart';
import 'package:lichess_mobile/src/view/drill/drill_summary.dart';
import 'package:lichess_mobile/src/view/user/perf_stats_screen.dart';
import 'package:lichess_mobile/src/widgets/adaptive_action_sheet.dart';
import 'package:lichess_mobile/src/widgets/feedback.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';
import 'package:lichess_mobile/src/widgets/platform_context_menu_button.dart';
import 'package:material_ui/material_ui.dart';

/// How far from the end of the list the next page of older Drills is loaded.
const _loadMoreExtent = 600.0;

/// The Drill History: the past Drills, newest first and grouped by day, under the charts of their
/// Drill Performance and share of puzzles solved.
///
/// A Drill is opened on its Drill Summary, and deleted with a long press. The Drill History of
/// every account on the device is saved to a file, and imported back, from the app bar menu.
///
/// Its route returns the weakest theme of a Drill Summary the player tapped, to set up a Drill
/// with.
class const DrillHistoryScreen({super.key}) extends ConsumerWidget {
  static Route<PuzzleAngle> buildRoute() {
    return buildScreenRoute(screen: const DrillHistoryScreen());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(drillHistoryProvider);
    return PlatformScaffold(
      appBar: const PlatformAppBar(
        title: Text(DrillStrings.historyTitle),
        largeTitle: true,
        actions: [_HistoryMenu()],
      ),
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

/// A provider for picking a Drill History file to import. Can be overridden in tests.
final pickDrillHistoryFileProvider = Provider<Future<PlatformFile?> Function()>((ref) {
  return () => FilePicker.pickFile(type: .custom, allowedExtensions: ['json']);
});

/// A provider for saving a Drill History file where the player chooses, returning where it was
/// saved, or `null` if they cancelled. Can be overridden in tests.
final saveDrillHistoryFileProvider =
    Provider<Future<Uri?> Function(String fileName, Uint8List bytes)>((ref) {
      return (fileName, bytes) => FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/json',
        type: .custom,
        allowedExtensions: ['json'],
      );
    });

/// The app bar menu of the Drill History: exporting it to a file, and importing one.
class const _HistoryMenu() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ContextMenuIconButton(
      semanticsLabel: DrillStrings.historyMenu,
      icon: const Icon(Icons.more_vert),
      actions: [
        ContextMenuAction(
          icon: Icons.upload_outlined,
          label: DrillStrings.exportHistory,
          onPressed: () => _export(ref, SnackBarPresenter.of(context)),
        ),
        ContextMenuAction(
          icon: Icons.download_outlined,
          label: DrillStrings.importHistory,
          onPressed: () => _import(context, ref),
        ),
      ],
    );
  }

  /// Saves the Drill History file, named with the date, where the player chooses in the system
  /// save dialog: on the device or in a cloud storage such as Drive.
  Future<void> _export(WidgetRef ref, SnackBarPresenter snackBar) async {
    try {
      final json = await ref.read(drillHistoryProvider.notifier).exportDrills();
      final name = 'drills-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json';
      final uri = await ref.read(saveDrillHistoryFileProvider)(name, utf8.encode(json));
      if (uri != null) snackBar.show(DrillStrings.historyExported);
    } catch (_) {
      snackBar.show(DrillStrings.couldNotExportHistory, type: .error);
    }
  }

  /// Adds the Drills of a picked Drill History file, and says how many were added.
  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final snackBar = SnackBarPresenter.of(context);
    try {
      final file = await ref.read(pickDrillHistoryFileProvider)();
      if (file == null) return;
      final json = await const Utf8Decoder().bind(file.readAsByteStream()).join();
      final (:added, :existing) = await ref.read(drillHistoryProvider.notifier).importDrills(json);
      snackBar.show(_importResultText(added: added, existing: existing));
    } on FormatException {
      snackBar.show(DrillStrings.invalidHistoryFile, type: .error);
    } catch (_) {
      snackBar.show(DrillStrings.couldNotImportHistory, type: .error);
    }
  }
}

/// What an import added to the Drill History, and what was already in it.
String _importResultText({required int added, required int existing}) {
  final addedText = switch (added) {
    0 => DrillStrings.noDrillAdded,
    1 => '1 ${DrillStrings.drillAdded}',
    _ => '$added ${DrillStrings.drillsAdded}',
  };
  if (existing == 0) return '$addedText.';
  return '$addedText; $existing '
      '${existing == 1 ? DrillStrings.alreadyInHistory : DrillStrings.alreadyInHistoryPlural}.';
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
    final changes = entries.map((e) => e.ratingChange).nonNulls;
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
        onTap: () async {
          final angle = await Navigator.of(context)
              .push(_DrillSummaryScreen.buildRoute(entry.startedAt));
          if (angle != null && context.mounted) Navigator.of(context).pop(angle);
        },
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
                      value: ratingChange == null ? '···' : formatRatingChange(ratingChange),
                      valueColor: ratingChange == null
                          ? textShade(context, Styles.subtitleOpacity)
                          : signColor(context, ratingChange),
                      detail: Row(
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
///
/// Its route returns the weakest theme the player tapped.
class const _DrillSummaryScreen(final DateTime startedAt) extends ConsumerWidget {
  static Route<PuzzleAngle> buildRoute(DateTime startedAt) {
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

/// The width kept left of the charts for the values of their axis, the same for both so that
/// their days line up.
const _axisWidth = 36.0;

/// The charts of the Drill History over the days of a range, as the puzzle rating history of the
/// profile: the Drill Performance above, the share of puzzles solved below, by day, week or month.
class const _ChartCard() extends ConsumerWidget {
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
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            Row(
              mainAxisAlignment: .spaceEvenly,
              children: [
                for (final choice in ranges)
                  ChartRangeButton(
                    text: switch (choice) {
                      .week => '1S',
                      .month => '1M',
                      .threeMonths => '3M',
                      .year => '1A',
                      .all => DrillStrings.allDays,
                    },
                    selected: choice == range,
                    onPressed: () =>
                        ref.read(drillChartPreferencesProvider.notifier).setRange(choice),
                  ),
              ],
            ),
            if (total == null)
              SizedBox(
                height: 120.0,
                child: Center(child: Text(DrillStrings.noChartData, style: subtitleStyle)),
              )
            else ...[
              const SizedBox(height: 4.0),
              Text(
                '${total.nbDrills} '
                '${total.nbDrills == 1 ? DrillStrings.drillUnit : DrillStrings.drillsUnit}, '
                '${total.nbPuzzles} '
                '${total.nbPuzzles == 1 ? DrillStrings.puzzleUnit : DrillStrings.puzzlesUnit} · '
                '${switch (series.grouping) {
                  .day => DrillStrings.byDay,
                  .week => DrillStrings.byWeek,
                  .month => DrillStrings.byMonth,
                }}',
                style: subtitleStyle,
              ),
              const SizedBox(height: 12.0),
              const Text(DrillStrings.performance, style: titleStyle),
              _PerformanceHeadline(series, range: range),
              const SizedBox(height: 8.0),
              SizedBox(height: 150.0, child: _PerformanceChart(series)),
              _DateAxis(series),
              const SizedBox(height: 16.0),
              const Text(DrillStrings.successes, style: titleStyle),
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
                    (context.lichessColors.good, DrillStrings.aboveExpected),
                    (ColorScheme.of(context).onSurface, DrillStrings.withinExpected),
                    (context.lichessColors.error, DrillStrings.belowExpected),
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
    final since = switch (range) {
      .week => DrillStrings.sinceLastWeek,
      .month => DrillStrings.sinceLastMonth,
      .threeMonths => DrillStrings.sinceLastThreeMonths,
      .year => DrillStrings.sinceLastYear,
      .all => '',
    };
    return _ChartHeadline(
      value: '$performance',
      comparison: change == null ? '' : '${formatRatingChange(change)} $since',
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
        final expected? => '${DrillStrings.expected} ${_percent(expected)} %',
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
                        '${_valueName(value, series.grouping)}\n${value.nbDrills} '
                        '${value.nbDrills == 1 ? DrillStrings.drillUnit : DrillStrings.drillsUnit}'
                        ', ${value.nbPuzzles} ${DrillStrings.puzzlesUnit}',
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
                        '${_valueName(value, series.grouping)}\n'
                        '$solved ${DrillStrings.ofTotal} ${value.nbPuzzles}'
                        '${value.expected != null ? ', ${DrillStrings.expected} ${_percent(value.expected!)} %' : ''}',
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
String _valueName(DrillChartValue value, DrillChartGrouping grouping) => switch (grouping) {
  .day => drillDayName(value.date, short: true),
  .week =>
    '${DrillStrings.weekOf} ${(value.date.year == DateTime.now().year ? DateFormat.MMMd() : DateFormat.yMMMd()).format(value.date)}',
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
