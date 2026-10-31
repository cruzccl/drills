import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/drill/drill_controller.dart';
import 'package:lichess_mobile/src/model/drill/drill_group.dart';
import 'package:lichess_mobile/src/model/drill/drill_history.dart';
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
import 'package:lichess_mobile/src/widgets/feedback.dart';
import 'package:lichess_mobile/src/widgets/list.dart';
import 'package:material_ui/material_ui.dart';

/// How much a share of puzzles solved must be above or below the share expected to be good or bad.
const _successRateMargin = 0.05;

/// The Drill Summary: what the Drill was and its share of puzzles solved, then its Drill
/// Performance and rating change, its solving times, its weakest themes and its puzzles, each
/// opened on the analysis board.
///
/// The puzzles can be narrowed down to the ones solved or the ones failed, which also fades the
/// bars of the others in the solving time chart.
///
/// A weakest theme goes back to the Drill home with that theme chosen: the route showing the
/// summary returns it. A Drill played signed out, without an account ([hasAccount] `false`), has
/// no rating change.
class const DrillSummary(final Drill drill, {final bool hasAccount = true, super.key})
    extends ConsumerStatefulWidget {
  @override
  ConsumerState<DrillSummary> createState() => _DrillSummaryState();
}

class _DrillSummaryState() extends ConsumerState<DrillSummary> {
  /// Whether the puzzles shown are the ones solved (`true`) or failed (`false`), or all of them
  /// (`null`).
  bool? _winShown;

  @override
  Widget build(BuildContext context) {
    final drill = widget.drill;
    final weakestThemes = drill.weakestThemes;
    return ListView(
      padding: Styles.bodyPadding.add(MediaQuery.paddingOf(context)),
      children: [
        _Headline(
          description: drillDescription(context, ref, drill),
          successes: drill.successes,
          nbPlayed: drill.results.length,
          expected: drill.expectedSuccessRate,
        ),
        const SizedBox(height: 20.0),
        _PerformanceCard(
          performance: drill.performance,
          isPerformanceReliable: drill.isPerformanceReliable,
          hasAccount: widget.hasAccount,
          ratingChange: drill.ratingChange,
          ratingRange: (drill.ratingBefore, drill.ratingAfter),
        ),
        const SizedBox(height: 20.0),
        _TimeCard(drill.results, winShown: _winShown),
        if (weakestThemes.isNotEmpty) ...[
          const SizedBox(height: 24.0),
          _WeakestThemes(weakestThemes),
        ],
        const SizedBox(height: 24.0),
        _PuzzleList(
          [drill].lock,
          winShown: _winShown,
          onWinShownChanged: (winShown) => setState(() => _winShown = winShown),
        ),
        const SizedBox(height: 20.0),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.drillL10n.backToHome),
        ),
      ],
    );
  }
}

/// The Drill Summary of several Drills of the same theme and difficulty taken as one, a
/// [DrillGroup].
///
/// It is a Drill's Drill Summary but for the rating change, the sum of the Drills' without the
/// rating before and after, and the solving times, without their chart. The puzzles are folded at
/// first, under a header per Drill.
///
/// Its route returns the weakest theme the player tapped, as a Drill's.
class const DrillGroupSummary(final DrillGroup group, {super.key}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<DrillGroupSummary> createState() => _DrillGroupSummaryState();
}

class _DrillGroupSummaryState() extends ConsumerState<DrillGroupSummary> {
  /// See [_DrillSummaryState._winShown].
  bool? _winShown;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final weakestThemes = group.weakestThemes;
    return ListView(
      padding: Styles.bodyPadding.add(MediaQuery.paddingOf(context)),
      children: [
        _Headline(
          description: drillGroupDescription(context, ref, group),
          successes: group.successes,
          nbPlayed: group.nbPlayed,
          expected: group.expectedSuccessRate,
        ),
        const SizedBox(height: 20.0),
        _PerformanceCard(
          performance: group.performance,
          isPerformanceReliable: group.isPerformanceReliable,
          hasAccount: true,
          ratingChange: group.ratingChange,
        ),
        const SizedBox(height: 20.0),
        _TimeCard(group.results, winShown: null, chart: false),
        if (weakestThemes.isNotEmpty) ...[
          const SizedBox(height: 24.0),
          _WeakestThemes(weakestThemes),
        ],
        const SizedBox(height: 24.0),
        _PuzzleList(
          group.drills,
          winShown: _winShown,
          onWinShownChanged: (winShown) => setState(() => _winShown = winShown),
          grouped: true,
        ),
        const SizedBox(height: 20.0),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.drillL10n.backToHome),
        ),
      ],
    );
  }
}

/// What the Drills were ([description]), their share of puzzles solved, large, and how it
/// compares with the share [expected].
class const _Headline({
  required final String description,
  required final int successes,
  required final int nbPlayed,
  required final double? expected,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final successRate = nbPlayed == 0 ? 0.0 : successes / nbPlayed;
    return Column(
      children: [
        Text(
          description,
          textAlign: .center,
          style: TextStyle(fontSize: 13, color: textShade(context, Styles.subtitleOpacity)),
        ),
        const SizedBox(height: 8.0),
        Text(
          '${(successRate * 100).round()} %',
          style: TextStyle(
            fontSize: 64,
            fontWeight: .bold,
            height: 1.1,
            color: successRateColor(context, successRate, expected),
          ),
        ),
        Text(
          context.drillL10n.nbSolvedOfTotal(successes, nbPlayed),
          style: const TextStyle(fontSize: 15),
        ),
        if (expected case final expected?) ...[
          const SizedBox(height: 10.0),
          _ExpectationBadge(successRate, expected),
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
        ? (Icons.trending_up, context.drillL10n.betterThanExpected, colors.good)
        : successRate <= expected - _successRateMargin
        ? (Icons.trending_down, context.drillL10n.worseThanExpected, colors.error)
        : (
            Icons.trending_flat,
            context.drillL10n.asExpected,
            ColorScheme.of(context).onSurfaceVariant,
          );
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
/// the Drill History cards, with the rating before and after ([ratingRange]) if given.
class const _PerformanceCard({
  required final int? performance,
  required final bool isPerformanceReliable,
  required final bool hasAccount,
  required final int? ratingChange,
  final (int?, int?)? ratingRange,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final change = ratingChange;
    final range = ratingRange;
    return Card(
      margin: .zero,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16.0))),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: .stretch,
          children: [
            Expanded(
              child: Opacity(
                opacity: isPerformanceReliable ? 1.0 : 0.55,
                child: _Metric(
                  label: context.drillL10n.performance,
                  value: performance?.toString() ?? '-',
                  valueColor: context.lichessColors.primary,
                  detail: isPerformanceReliable ? null : Text(context.drillL10n.unreliable),
                ),
              ),
            ),
            if (hasAccount) ...[
              const VerticalDivider(width: 1.0, thickness: 1.0),
              Expanded(
                child: _Metric(
                  label: context.drillL10n.points,
                  value: change == null ? '···' : formatRatingChange(change),
                  valueColor: change == null
                      ? textShade(context, Styles.subtitleOpacity)
                      : signColor(context, change),
                  detail: range == null
                      ? null
                      : Row(
                          mainAxisSize: .min,
                          spacing: 3.0,
                          children: [
                            Text(range.$1?.toString() ?? '?'),
                            const Icon(Icons.arrow_forward, size: 12),
                            Text(range.$2?.toString() ?? '?'),
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

/// The time spent solving the puzzles, in total and on average, and, with a [chart], on each of
/// them, the puzzles not shown in the list ([winShown]) faded.
class const _TimeCard(
  final IList<DrillPuzzleResult> results, {
  required final bool? winShown,
  final bool chart = true,
}) extends StatelessWidget {
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
                Text(
                  context.drillL10n.time,
                  style: const TextStyle(fontSize: 17, fontWeight: .bold),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: context.drillL10n.totalTime,
                    value: formatSolvingTime(total),
                    padding: .zero,
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: context.drillL10n.averageTime,
                    value: formatSolvingTime(average),
                    padding: .zero,
                  ),
                ),
              ],
            ),
            if (chart && results.isNotEmpty) ...[
              const SizedBox(height: 12.0),
              SizedBox(height: 64.0, child: _SolvingTimeChart(results, winShown: winShown)),
            ],
          ],
        ),
      ),
    );
  }
}

/// A bar per puzzle of the Drill, as high as the time spent solving it and colored by its
/// result, faded unless its result is [winShown], under a dashed line at the average time. A bar
/// opens its puzzle on the analysis board.
class const _SolvingTimeChart(
  final IList<DrillPuzzleResult> results, {
  required final bool? winShown,
}) extends ConsumerWidget {
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
                      color: (result.win ? colors.good : colors.error).withValues(
                        alpha: winShown == null || winShown == result.win ? 1.0 : 0.2,
                      ),
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
class const _WeakestThemes(final IList<DrillWeakTheme> themes) extends StatelessWidget {
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
              Text(context.drillL10n.weakestThemes, style: Styles.sectionTitle),
              Text(
                context.drillL10n.weakestThemesHint,
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
class const _ThemeCard(final DrillWeakTheme data) extends StatelessWidget {
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
                    context.drillL10n.train,
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

/// The puzzles of the [drills], under a header that folds and unfolds them, with its counts of
/// puzzles solved and failed, each showing only those puzzles until tapped again.
///
/// The puzzles of [grouped] Drills are folded at first, under a header per Drill, left out when
/// none of its puzzles is shown.
class const _PuzzleList(
  final IList<Drill> drills, {
  required final bool? winShown,
  required final ValueChanged<bool?> onWinShownChanged,
  final bool grouped = false,
}) extends StatefulWidget {
  @override
  State<_PuzzleList> createState() => _PuzzleListState();
}

class _PuzzleListState() extends State<_PuzzleList> {
  late bool _isExpanded = !widget.grouped;

  @override
  Widget build(BuildContext context) {
    final results = widget.drills.expand((d) => d.results);
    final nb = results.length;
    final successes = results.where((r) => r.win).length;
    final winShown = widget.winShown;
    List<Widget> tiles(Drill drill) => [
      for (final result in drill.results)
        if (winShown == null || result.win == winShown) _DrillPuzzleResultTile(result),
    ];
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
                        context.drillL10n.themePuzzles(nb),
                        style: const TextStyle(fontSize: 16, fontWeight: .w500),
                      ),
                    ),
                    Row(
                      spacing: 6.0,
                      children: [
                        for (final (win, count) in [(true, successes), (false, nb - successes)])
                          _ResultCountButton(
                            win: win,
                            count: count,
                            selected: winShown == win,
                            faded: winShown == !win,
                            onTap: () {
                              widget.onWinShownChanged(winShown == win ? null : win);
                              setState(() => _isExpanded = true);
                            },
                          ),
                      ],
                    ),
                    Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_isExpanded)
          if (!widget.grouped)
            ListSection(margin: .zero, hasLeading: true, children: tiles(widget.drills.single))
          else
            for (final drill in widget.drills)
              if (tiles(drill) case final drillTiles when drillTiles.isNotEmpty) ...[
                _DrillHeader(drill, winShown: winShown),
                ListSection(margin: .zero, hasLeading: true, children: drillTiles),
              ],
      ],
    );
  }
}

/// The header of a Drill's puzzles in the Drill Summary of several Drills: when it started, its
/// puzzles solved and the result of each, those not shown in the list ([winShown]) faded.
class const _DrillHeader(final Drill drill, {required final bool? winShown})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final subtitleStyle = TextStyle(
      fontSize: 13,
      color: textShade(context, Styles.subtitleOpacity),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4.0, 8.0, 4.0, 2.0),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: 6.0,
        children: [
          Row(
            crossAxisAlignment: .baseline,
            textBaseline: .alphabetic,
            spacing: 8.0,
            children: [
              Expanded(
                child: Text(
                  [
                    '${drillDayName(context, drill.startedAt)} ${DateFormat.Hm().format(drill.startedAt)}',
                    if (drill.isPartial) context.drillL10n.partial,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 14, fontWeight: .w500),
                ),
              ),
              Text('${drill.successes} / ${drill.results.length}', style: subtitleStyle),
            ],
          ),
          DrillResultsBar(DrillHistoryEntry.of(drill), winShown: winShown),
        ],
      ),
    );
  }
}

/// The number of puzzles solved ([win]) or failed, as a pill that shows only those puzzles, filled
/// when [selected], faded when the others are shown.
class const _ResultCountButton({
  required final bool win,
  required final int count,
  required final bool selected,
  required final bool faded,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final color = win ? context.lichessColors.good : context.lichessColors.error;
    return Opacity(
      opacity: faded ? 0.45 : 1.0,
      child: Material(
        color: selected ? color : color.withValues(alpha: 0.15),
        shape: const StadiumBorder(),
        clipBehavior: .antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Semantics(
            button: true,
            selected: selected,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
              child: Text(
                '$count ${win ? '✓' : '✗'}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: .w500,
                  color: selected ? Colors.white : color,
                ),
              ),
            ),
          ),
        ),
      ),
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
                ? context.drillL10n.unrated
                : ratingDiff == null
                ? context.drillL10n.pending
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
    context.drillL10n.nbPuzzles(config.nbPuzzles),
    puzzleDifficultyL10n(context, config.difficulty),
    '${drillDayName(context, drill.startedAt)} ${DateFormat.Hm().format(drill.startedAt)}',
    if (drill.isPartial) context.drillL10n.partial,
  ].join(' · ');
}

/// What the Drills of [group] were: their theme and difficulty, and the days they were played.
String drillGroupDescription(BuildContext context, WidgetRef ref, DrillGroup group) {
  final config = group.config;
  final first = drillDayName(context, group.drills.first.startedAt, short: true);
  final last = drillDayName(context, group.drills.last.startedAt, short: true);
  return [
    drillAngleName(context, ref, config.angle),
    puzzleDifficultyL10n(context, config.difficulty),
    if (first == last) first else '$first – $last',
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

/// Formats a solving time as minutes and seconds, such as 2:05, or from one hour on as hours,
/// minutes and seconds, such as 3:10:13.
String formatSolvingTime(Duration duration) {
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  if (duration.inHours == 0) return '${duration.inMinutes}:$seconds';
  final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
  return '${duration.inHours}:$minutes:$seconds';
}

String _themeName(BuildContext context, String theme) =>
    puzzleThemeNameMap.get(theme)?.l10n(context.l10n).name ?? theme;

/// The puzzle from the local storage, where the puzzles solved are saved, or else from the server.
Future<Puzzle> _loadPuzzle(WidgetRef ref, PuzzleId id) async {
  final storage = await ref.read(puzzleStorageProvider.future);
  return await storage.fetch(puzzleId: id) ?? await ref.read(puzzleRepositoryProvider).fetch(id);
}
