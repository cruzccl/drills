import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/drill/drill_controller.dart';
import 'package:lichess_mobile/src/model/drill/drill_puzzle_analysis.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_angle.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_difficulty.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_repository.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_storage.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_theme.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/view/analysis/analysis_screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_angle_screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_history_screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_strings.dart';
import 'package:lichess_mobile/src/widgets/feedback.dart';
import 'package:lichess_mobile/src/widgets/list.dart';
import 'package:material_ui/material_ui.dart';

/// How much a share of puzzles solved must be above or below the share expected to be good or bad.
const _successRateMargin = 0.05;

/// The Drill Summary: what the Drill was and its share of puzzles solved, then its Drill
/// Performance and rating change, its solving times, its weakest themes and its puzzles, each
/// opened on the analysis board.
///
/// A weakest theme goes back to the Drill home with that theme chosen: the route showing the
/// summary returns it. A Drill played signed out, without an account ([hasAccount] `false`), has
/// no rating change.
class const DrillSummary(final Drill drill, {final bool hasAccount = true, super.key})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weakestThemes = drill.weakestThemes;
    return ListView(
      padding: Styles.bodyPadding.add(MediaQuery.paddingOf(context)),
      children: [
        _Headline(drill),
        const SizedBox(height: 20.0),
        _PerformanceCard(drill, hasAccount: hasAccount),
        const SizedBox(height: 20.0),
        _TimeCard(drill.results),
        if (weakestThemes.isNotEmpty) ...[
          const SizedBox(height: 24.0),
          _WeakestThemes(weakestThemes),
        ],
        const SizedBox(height: 24.0),
        _PuzzleList(drill.results),
        const SizedBox(height: 20.0),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(DrillStrings.backToHome),
        ),
      ],
    );
  }
}

/// What the Drill was, its share of puzzles solved, large, and how it compares with the share
/// expected.
class const _Headline(final Drill drill) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expected = drill.expectedSuccessRate;
    final nbPlayed = drill.results.length;
    return Column(
      children: [
        Text(
          drillDescription(context, ref, drill),
          textAlign: .center,
          style: TextStyle(fontSize: 13, color: textShade(context, Styles.subtitleOpacity)),
        ),
        const SizedBox(height: 8.0),
        Text(
          '${(drill.successRate * 100).round()} %',
          style: TextStyle(
            fontSize: 64,
            fontWeight: .bold,
            height: 1.1,
            color: successRateColor(context, drill.successRate, expected),
          ),
        ),
        Text(
          '${drill.successes} ${DrillStrings.ofTotal} $nbPlayed '
          '${nbPlayed == 1 ? DrillStrings.solvedUnit : DrillStrings.solvedUnitPlural}',
          style: const TextStyle(fontSize: 15),
        ),
        if (expected != null) ...[
          const SizedBox(height: 10.0),
          _ExpectationBadge(drill.successRate, expected),
        ],
      ],
    );
  }
}

/// Whether a share of puzzles solved is better or worse than the share [expected], or as
/// expected, with the share expected.
class const _ExpectationBadge(final double successRate, final double expected)
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.lichessColors;
    final (icon, text, color) = successRate >= expected + _successRateMargin
        ? (Icons.trending_up, DrillStrings.betterThanExpected, colors.good)
        : successRate <= expected - _successRateMargin
        ? (Icons.trending_down, DrillStrings.worseThanExpected, colors.error)
        : (Icons.trending_flat, DrillStrings.asExpected, ColorScheme.of(context).onSurfaceVariant);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: const BorderRadius.all(Radius.circular(16.0)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        child: Row(
          mainAxisSize: .min,
          spacing: 6.0,
          children: [
            Icon(icon, size: 16, color: color),
            Text(
              '$text (${(expected * 100).round()} %)',
              style: TextStyle(fontSize: 13, fontWeight: .w500, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Drill Performance and, with an account, the rating change, side by side in the order of
/// the Drill History cards.
class const _PerformanceCard(final Drill drill, {required final bool hasAccount})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final performance = drill.performance;
    final ratingChange = drill.ratingChange;
    return Card(
      margin: .zero,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16.0))),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: .stretch,
          children: [
            Expanded(
              child: Opacity(
                opacity: drill.isPerformanceReliable ? 1.0 : 0.55,
                child: _Metric(
                  label: DrillStrings.performance,
                  value: performance?.toString() ?? '-',
                  valueColor: context.lichessColors.primary,
                  detail: drill.isPerformanceReliable ? null : const Text(DrillStrings.unreliable),
                ),
              ),
            ),
            if (hasAccount) ...[
              const VerticalDivider(width: 1.0, thickness: 1.0),
              Expanded(
                child: _Metric(
                  label: DrillStrings.points,
                  value: ratingChange == null ? '···' : formatRatingChange(ratingChange),
                  valueColor: ratingChange == null
                      ? textShade(context, Styles.subtitleOpacity)
                      : signColor(context, ratingChange),
                  detail: Row(
                    mainAxisSize: .min,
                    spacing: 3.0,
                    children: [
                      Text(drill.ratingBefore?.toString() ?? '?'),
                      const Icon(Icons.arrow_forward, size: 12),
                      Text(drill.ratingAfter?.toString() ?? '?'),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A figure of the Drill Summary: its label above its value, followed by its detail.
class const _Metric({
  required final String label,
  required final String value,
  final Color? valueColor,
  final Widget? detail,
  final EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final subtitleColor = textShade(context, Styles.subtitleOpacity);
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: .start,
        mainAxisAlignment: .center,
        spacing: 2.0,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: subtitleColor)),
          Row(
            crossAxisAlignment: .baseline,
            textBaseline: .alphabetic,
            spacing: 8.0,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 20, fontWeight: .bold, color: valueColor),
              ),
              if (detail != null)
                Flexible(
                  child: DefaultTextStyle.merge(
                    style: TextStyle(fontSize: 13, color: subtitleColor),
                    child: detail!,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The time spent solving the Drill's puzzles, in total and on average, and on each of them.
class const _TimeCard(final IList<DrillPuzzleResult> results) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final total = results.fold(Duration.zero, (total, r) => total + r.solvingTime);
    final average = results.isEmpty ? Duration.zero : total ~/ results.length;
    return Card(
      margin: .zero,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16.0))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            Row(
              spacing: 8.0,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 18,
                  color: textShade(context, Styles.subtitleOpacity),
                ),
                const Text(DrillStrings.time, style: TextStyle(fontSize: 17, fontWeight: .bold)),
              ],
            ),
            const SizedBox(height: 12.0),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: DrillStrings.totalTime,
                    value: formatSolvingTime(total),
                    padding: .zero,
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: DrillStrings.averageTime,
                    value: formatSolvingTime(average),
                    padding: .zero,
                  ),
                ),
              ],
            ),
            if (results.isNotEmpty) ...[
              const SizedBox(height: 12.0),
              SizedBox(height: 64.0, child: _SolvingTimeChart(results)),
            ],
          ],
        ),
      ),
    );
  }
}

/// A bar per puzzle of the Drill, as high as the time spent solving it and colored by its
/// result, under a dashed line at the average time. A bar opens its puzzle on the analysis
/// board.
class const _SolvingTimeChart(final IList<DrillPuzzleResult> results) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.lichessColors;
    final seconds = [for (final r in results) r.solvingTime.inMilliseconds / 1000];
    final maxY = math.max(seconds.max, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final slot = constraints.maxWidth / results.length;
        final barWidth = (slot - (results.length > 20 ? 2 : 4)).clamp(1.0, 32.0);
        return BarChart(
          BarChartData(
            minY: 0,
            maxY: maxY,
            alignment: .spaceAround,
            barGroups: [
              for (final (i, result) in results.indexed)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: seconds[i],
                      width: barWidth,
                      color: result.win ? colors.good : colors.error,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(barWidth > 6 ? 3.0 : 1.0),
                      ),
                      // The whole height of a bar's slot can be tapped, however short the bar.
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxY,
                        color: Colors.transparent,
                      ),
                    ),
                  ],
                ),
            ],
            borderData: FlBorderData(
              show: true,
              border: Border(bottom: BorderSide(color: ColorScheme.of(context).outlineVariant)),
            ),
            gridData: const FlGridData(show: false),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                if (results.length > 1)
                  HorizontalLine(
                    y: seconds.average,
                    color: textShade(context, 0.5),
                    strokeWidth: 1,
                    dashArray: const [4, 4],
                  ),
              ],
            ),
            titlesData: const FlTitlesData(show: false),
            barTouchData: BarTouchData(
              handleBuiltInTouches: false,
              allowTouchBarBackDraw: true,
              touchCallback: (event, response) {
                final spot = response?.spot;
                if (event is FlTapUpEvent && spot != null) {
                  _openAnalysis(context, ref, results[spot.touchedBarGroupIndex].id);
                }
              },
            ),
          ),
        );
      },
    );
  }
}

/// The weakest themes of the Drill, side by side, each going back to the Drill home with that
/// theme chosen.
class const _WeakestThemes(final IList<({String theme, int failures, int puzzles})> themes)
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Column(
            crossAxisAlignment: .start,
            spacing: 2.0,
            children: [
              const Text(DrillStrings.weakestThemes, style: Styles.sectionTitle),
              Text(
                DrillStrings.weakestThemesHint,
                style: TextStyle(fontSize: 13, color: textShade(context, Styles.subtitleOpacity)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10.0),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: .stretch,
            spacing: 8.0,
            children: [
              // Always as many slots, so that a card keeps its width when there are fewer themes.
              for (var i = 0; i < kMaxWeakestThemes; i++)
                Expanded(
                  child: i < themes.length ? _ThemeCard(themes[i]) : const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A weakest theme: how many of its puzzles were failed, and a button to train it.
class const _ThemeCard(final ({String theme, int failures, int puzzles}) data)
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final key = puzzleThemeNameMap.get(data.theme);
    final primary = context.lichessColors.primary;
    return Card(
      margin: .zero,
      clipBehavior: .antiAlias,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14.0))),
      child: InkWell(
        onTap: key == null ? null : () => Navigator.of(context).pop(PuzzleTheme(key)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: .start,
            spacing: 8.0,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${data.failures}',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: .bold,
                        color: context.lichessColors.error,
                      ),
                    ),
                    TextSpan(
                      text: ' / ${data.puzzles}',
                      style: TextStyle(
                        fontSize: 14,
                        color: textShade(context, Styles.subtitleOpacity),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  _themeName(context, data.theme),
                  style: const TextStyle(fontSize: 14, fontWeight: .w500, height: 1.25),
                ),
              ),
              Row(
                mainAxisSize: .min,
                children: [
                  Text(
                    DrillStrings.train,
                    style: TextStyle(fontSize: 13, fontWeight: .w500, color: primary),
                  ),
                  Icon(Icons.chevron_right, size: 16, color: primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The puzzles of the Drill, under a header that folds and unfolds them.
class const _PuzzleList(final IList<DrillPuzzleResult> results) extends StatefulWidget {
  @override
  State<_PuzzleList> createState() => _PuzzleListState();
}

class _PuzzleListState() extends State<_PuzzleList> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final results = widget.results;
    final nb = results.length;
    final successes = results.where((r) => r.win).length;
    return Column(
      crossAxisAlignment: .stretch,
      spacing: 8.0,
      children: [
        Card(
          margin: .zero,
          clipBehavior: .antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16.0)),
          ),
          child: InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                height: 52.0,
                child: Row(
                  spacing: 10.0,
                  children: [
                    Expanded(
                      child: Text(
                        nb == 1
                            ? DrillStrings.onePuzzle
                            : '${DrillStrings.allPuzzles} $nb ${DrillStrings.puzzlesUnit}',
                        style: const TextStyle(fontSize: 16, fontWeight: .w500),
                      ),
                    ),
                    Text(
                      '$successes ✓ · ${nb - successes} ✗',
                      style: TextStyle(
                        fontSize: 13,
                        color: textShade(context, Styles.subtitleOpacity),
                      ),
                    ),
                    Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_isExpanded)
          ListSection(
            margin: .zero,
            hasLeading: true,
            children: [for (final result in results) _DrillPuzzleResultTile(result)],
          ),
      ],
    );
  }
}

class const _DrillPuzzleResultTile(final DrillPuzzleResult result) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.lichessColors;
    final ratingDiff = result.ratingDiff;
    return ListTile(
      leading: result.win
          ? Icon(Icons.check, color: colors.good)
          : Icon(Icons.close, color: colors.error),
      title: Text('${result.puzzleRating}'),
      subtitle: Text(
        result.themes.map((t) => _themeName(context, t)).join(', '),
        maxLines: 2,
        overflow: .ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: .center,
        crossAxisAlignment: .end,
        children: [
          Text(
            !result.rated
                ? DrillStrings.unrated
                : ratingDiff == null
                ? DrillStrings.pending
                : formatRatingChange(ratingDiff),
            style: TextStyle(color: ratingDiff != null ? signColor(context, ratingDiff) : null),
          ),
          Text(formatSolvingTime(result.solvingTime), style: TextTheme.of(context).bodySmall),
        ],
      ),
      onTap: () => _openAnalysis(context, ref, result.id),
    );
  }
}

/// The puzzle [id] of a Drill opened on the analysis board.
Future<void> _openAnalysis(BuildContext context, WidgetRef ref, PuzzleId id) async {
  try {
    final puzzle = await _loadPuzzle(ref, id);
    if (context.mounted) {
      Navigator.of(context)
          .push(AnalysisScreen.buildRoute(drillPuzzleAnalysisOptions(puzzle), isDrill: true));
    }
  } catch (_) {
    if (context.mounted) {
      showSnackBar(context, 'Could not load the puzzle', type: .error);
    }
  }
}

/// What [drill] was: its theme, number of puzzles and difficulty, when it started, and whether it
/// is a Partial Drill.
String drillDescription(BuildContext context, WidgetRef ref, Drill drill) {
  final config = drill.config;
  return [
    drillAngleName(context, ref, config.angle),
    '${config.nbPuzzles} ${config.nbPuzzles == 1 ? DrillStrings.puzzleUnit : DrillStrings.puzzlesUnit}',
    puzzleDifficultyL10n(context, config.difficulty),
    '${drillDayName(drill.startedAt)} ${DateFormat.Hm().format(drill.startedAt)}',
    if (drill.isPartial) DrillStrings.partial,
  ].join(' · ');
}

/// Formats a rating change with its sign, such as +10, −10 or ±0.
String formatRatingChange(int value) => value > 0
    ? '+$value'
    : value < 0
    ? '−${-value}'
    : '±0';

/// Green or red when [successRate] is clearly above or below the share [expected], else `null` for
/// the text color, as when the share expected is not known.
Color? successRateColor(BuildContext context, double successRate, double? expected) {
  if (expected == null) return null;
  final colors = context.lichessColors;
  return successRate >= expected + _successRateMargin
      ? colors.good
      : successRate <= expected - _successRateMargin
      ? colors.error
      : null;
}

/// Green for a gain, red for a loss, `null` for the text color when there is no change.
Color? signColor(BuildContext context, int change) => change > 0
    ? context.lichessColors.good
    : change < 0
    ? context.lichessColors.error
    : null;

/// Formats a solving time as minutes and seconds, such as 2:05.
String formatSolvingTime(Duration duration) {
  final seconds = duration.inSeconds;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

String _themeName(BuildContext context, String theme) =>
    puzzleThemeNameMap.get(theme)?.l10n(context.l10n).name ?? theme;

/// The puzzle from the local storage, where the puzzles solved are saved, or else from the server.
Future<Puzzle> _loadPuzzle(WidgetRef ref, PuzzleId id) async {
  final storage = await ref.read(puzzleStorageProvider.future);
  return await storage.fetch(puzzleId: id) ?? await ref.read(puzzleRepositoryProvider).fetch(id);
}
