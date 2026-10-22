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

/// The Drill Summary: what the Drill was, its results, rating change, solving time, Drill
/// Performance and weakest themes, then its puzzles, each opened on the analysis board.
class const DrillSummary(final Drill drill, {super.key}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final performance = drill.performance;
    return ListView(
      padding: Styles.bodyPadding.add(MediaQuery.paddingOf(context)),
      children: [
        Text(drillDescription(context, ref, drill), style: TextTheme.of(context).titleMedium),
        const SizedBox(height: 16.0),
        ListSection(
          margin: .zero,
          children: [
            _SummaryTile(DrillStrings.successes, '${drill.successes}'),
            _SummaryTile(DrillStrings.failures, '${drill.failures}'),
            _SummaryTile(DrillStrings.successRate, '${(drill.successRate * 100).round()} %'),
            _SummaryTile(DrillStrings.rating, _ratingText(drill)),
            _SummaryTile(DrillStrings.totalTime, formatSolvingTime(drill.totalSolvingTime)),
            _SummaryTile(DrillStrings.averageTime, formatSolvingTime(drill.averageSolvingTime)),
            Opacity(
              opacity: drill.isPerformanceReliable ? 1.0 : 0.5,
              child: _SummaryTile(
                DrillStrings.performance,
                performance != null ? '$performance' : '-',
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

class const _SummaryTile(final String label, final String value, {final String? subtitle})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: Text(value, style: TextTheme.of(context).titleMedium),
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
                : _signed(ratingDiff),
            style: TextStyle(
              color: ratingDiff == null || ratingDiff == 0
                  ? null
                  : ratingDiff > 0
                  ? colors.good
                  : colors.error,
            ),
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

String _ratingText(Drill drill) {
  final before = drill.ratingBefore?.toString() ?? '?';
  final after = drill.ratingAfter;
  final change = drill.ratingChange;
  return after == null
      ? '$before → ${DrillStrings.pending}'
      : '$before → $after${change != null ? ' (${_signed(change)})' : ''}';
}

String _signed(int value) => value > 0 ? '+$value' : '$value';

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
