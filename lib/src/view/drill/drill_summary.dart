import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/drill/drill_controller.dart';
import 'package:lichess_mobile/src/model/drill/drill_puzzle_analysis.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_difficulty.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_repository.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_storage.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_theme.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/view/analysis/analysis_screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_angle_screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_strings.dart';
import 'package:lichess_mobile/src/widgets/feedback.dart';
import 'package:lichess_mobile/src/widgets/list.dart';
import 'package:lichess_mobile/src/widgets/platform_filled_button.dart';
import 'package:material_ui/material_ui.dart';

/// How much a share of puzzles solved must be above or below the share expected to be good or bad.
const _successRateMargin = 0.05;

/// The Drill Summary: what the Drill was, its results, rating change, solving time, Drill
/// Performance and weakest themes, then its puzzles, each opened on the analysis board.
///
/// A Drill played signed out, without an account ([hasAccount] `false`), has no rating row.
class const DrillSummary(final Drill drill, {final bool hasAccount = true, super.key})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final performance = drill.performance;
    final colors = context.lichessColors;
    return ListView(
      padding: Styles.bodyPadding.add(MediaQuery.paddingOf(context)),
      children: [
        Text(drillDescription(context, ref, drill), style: TextTheme.of(context).titleMedium),
        const SizedBox(height: 16.0),
        ListSection(
          margin: .zero,
          children: [
            _SummaryTile(
              DrillStrings.successes,
              '${drill.successes}',
              valueColor: drill.successes > 0 ? colors.good : null,
            ),
            _SummaryTile(
              DrillStrings.failures,
              '${drill.failures}',
              valueColor: drill.failures > 0 ? colors.error : null,
            ),
            _SummaryTile(
              DrillStrings.successRate,
              '${(drill.successRate * 100).round()} %',
              valueColor: successRateColor(context, drill.successRate, drill.expectedSuccessRate),
              subtitle: switch (drill.expectedSuccessRate) {
                final expected? => '${DrillStrings.expected} ${(expected * 100).round()} %',
                null => null,
              },
            ),
            if (hasAccount)
              Opacity(
                opacity: drill.isCasual ? 0.5 : 1.0,
                child: ListTile(
                  title: const Text(DrillStrings.rating),
                  trailing: _RatingChange(drill),
                ),
              ),
            _SummaryTile(DrillStrings.totalTime, formatSolvingTime(drill.totalSolvingTime)),
            _SummaryTile(DrillStrings.averageTime, formatSolvingTime(drill.averageSolvingTime)),
            Opacity(
              opacity: drill.isPerformanceReliable ? 1.0 : 0.5,
              child: _SummaryTile(
                DrillStrings.performance,
                performance != null ? '$performance' : '-',
                valueColor: performance != null ? colors.primary : null,
                subtitle: drill.isPerformanceReliable ? null : DrillStrings.unreliable,
              ),
            ),
          ],
        ),
        if (drill.weakestThemes.isNotEmpty)
          ListSection(
            header: const Text(DrillStrings.weakestThemes),
            children: [
              for (final (:theme, :failures) in drill.weakestThemes)
                ListTile(title: Text('${_themeName(context, theme)} ($failures)')),
            ],
          ),
        ListSection(
          header: const Text(DrillStrings.puzzleList),
          hasLeading: true,
          children: [for (final result in drill.results) _DrillPuzzleResultTile(result)],
        ),
        const SizedBox(height: 8.0),
        PlatformFilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(DrillStrings.backToHome),
        ),
      ],
    );
  }
}

class const _SummaryTile(
  final String label,
  final String value, {
  final String? subtitle,
  final Color? valueColor,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: Text(value, style: TextTheme.of(context).titleMedium?.copyWith(color: valueColor)),
    );
  }
}

/// The rating before and after [drill], and its change, green or red as in the Drill History cards,
/// with the same centered arrow (the → character sits below the middle of the digits).
class const _RatingChange(final Drill drill) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final style = TextTheme.of(context).titleMedium;
    final after = drill.ratingAfter;
    final change = drill.ratingChange;
    return Row(
      mainAxisSize: .min,
      spacing: 4.0,
      children: [
        Text(drill.ratingBefore?.toString() ?? '?', style: style),
        const Icon(Icons.arrow_forward, size: 16),
        Text(after?.toString() ?? DrillStrings.pending, style: style),
        if (after != null && change != null)
          Text(
            '(${formatRatingChange(change)})',
            style: style?.copyWith(color: signColor(context, change)),
          ),
      ],
    );
  }
}

class const _DrillPuzzleResultTile(final DrillPuzzleResult result) extends ConsumerWidget {
  Future<void> _openAnalysis(BuildContext context, WidgetRef ref) async {
    try {
      final puzzle = await _loadPuzzle(ref, result.id);
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
      onTap: () => _openAnalysis(context, ref),
    );
  }
}

/// What [drill] was: its number of puzzles, theme and difficulty, and whether it is a Partial
/// Drill.
String drillDescription(BuildContext context, WidgetRef ref, Drill drill) {
  final config = drill.config;
  return [
    '${config.nbPuzzles} ${config.nbPuzzles == 1 ? DrillStrings.puzzleUnit : DrillStrings.puzzlesUnit}',
    drillAngleName(context, ref, config.angle),
    puzzleDifficultyL10n(context, config.difficulty),
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
