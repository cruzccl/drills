import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/drill/drill_controller.dart';
import 'package:lichess_mobile/src/model/drill/drill_history.dart';
import 'package:lichess_mobile/src/model/settings/board_preferences.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/widgets/non_linear_slider.dart';
import 'package:lichess_mobile/src/widgets/platform_choice_chip.dart';
import 'package:material_ui/material_ui.dart';

/// The numbers of puzzles offered with one tap.
const _quickPickNbPuzzles = [5, 10, 12, 15, 20, 25];

/// Every number of puzzles a Drill can have, along the slider.
final _sliderNbPuzzles = [for (var nb = 1; nb <= kMaxDrillPuzzles; nb++) nb];

/// The average time the player spent on a puzzle in their latest Drills, or `null` if not known
/// yet.
///
/// It reads [recentDrillsProvider], which the caller watches so that it is loaded.
Duration? recentTimePerPuzzle(WidgetRef ref) {
  final results = [
    for (final drill in ref.read(recentDrillsProvider).value ?? const IListConst<Drill>([]))
      for (final result in drill.results)
        if (result.solvingTime > Duration.zero) result,
  ];
  if (results.isEmpty) return null;
  return results.fold(Duration.zero, (total, r) => total + r.solvingTime) ~/ results.length;
}

/// Chooses a number of puzzles, which its route returns once done: one more or less, a number
/// offered, or any along the slider.
///
/// It is the number of puzzles of the next Drill, or with a [title] and an [actionLabel], of an
/// extension of a Drill.
class const NbPuzzlesSheet({
  required final int initial,

  /// The number chosen the last time.
  required final int last,

  /// The average time the player spends on a puzzle, to tell how long the puzzles take, if known.
  required final Duration? timePerPuzzle,

  /// The title of the sheet, the number of puzzles of a Drill if `null`.
  final String? title,

  /// The label of the button that returns the number chosen, "Done" if `null`.
  final String Function(int nbPuzzles)? actionLabel,
}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<NbPuzzlesSheet> createState() => _NbPuzzlesSheetState();
}

class _NbPuzzlesSheetState() extends ConsumerState<NbPuzzlesSheet> {
  late int _nbPuzzles = widget.initial;

  void _set(int nbPuzzles) {
    if (nbPuzzles == _nbPuzzles || nbPuzzles < 1 || nbPuzzles > kMaxDrillPuzzles) return;
    if (ref.read(boardPreferencesProvider).hapticFeedback) HapticFeedback.selectionClick();
    setState(() => _nbPuzzles = nbPuzzles);
  }

  @override
  Widget build(BuildContext context) {
    final subtitleStyle = TextStyle(
      fontSize: 13,
      color: textShade(context, Styles.subtitleOpacity),
    );
    final timePerPuzzle = widget.timePerPuzzle;
    final minutes = timePerPuzzle == null
        ? null
        : ((timePerPuzzle * _nbPuzzles).inSeconds / 60).round().clamp(1, 999);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          Row(
            crossAxisAlignment: .baseline,
            textBaseline: .alphabetic,
            children: [
              Expanded(
                child: Text(
                  widget.title ?? context.drillL10n.nbPuzzlesChoice,
                  style: const TextStyle(fontSize: 18, fontWeight: .w600),
                ),
              ),
              Text(context.drillL10n.lastNbPuzzles(widget.last), style: subtitleStyle),
            ],
          ),
          const SizedBox(height: 16.0),
          Row(
            mainAxisAlignment: .center,
            spacing: 24.0,
            children: [
              IconButton.outlined(
                tooltip: context.drillL10n.onePuzzleLess,
                iconSize: 26.0,
                padding: const EdgeInsets.all(14.0),
                onPressed: _nbPuzzles > 1 ? () => _set(_nbPuzzles - 1) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 120.0,
                child: Column(
                  children: [
                    Text(
                      '$_nbPuzzles',
                      style: const TextStyle(fontSize: 72, fontWeight: .w300, height: 1.0),
                    ),
                    Text(context.drillL10n.puzzlesLabel(_nbPuzzles), style: subtitleStyle),
                  ],
                ),
              ),
              IconButton.outlined(
                tooltip: context.drillL10n.onePuzzleMore,
                iconSize: 26.0,
                padding: const EdgeInsets.all(14.0),
                onPressed: _nbPuzzles < kMaxDrillPuzzles ? () => _set(_nbPuzzles + 1) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          // Spread across the width, in line with the slider below, unlike a [Filter]. Without a
          // checkmark, a selected chip keeps its width and doesn't move the others.
          Wrap(
            alignment: .spaceBetween,
            spacing: 8.0,
            runSpacing: Theme.of(context).platform == .iOS ? 8.0 : 0.0,
            children: [
              for (final nb in _quickPickNbPuzzles)
                PlatformChoiceChip(
                  label: Text('$nb'),
                  selected: nb == _nbPuzzles,
                  showCheckmark: false,
                  onSelected: (_) => _set(nb),
                ),
            ],
          ),
          NonLinearSlider(
            value: _nbPuzzles,
            values: _sliderNbPuzzles,
            onChange: (nb) => _set(nb.toInt()),
            // The number of puzzles is already set while dragging.
            onChangeEnd: (_) {},
          ),
          if (minutes != null) ...[
            const SizedBox(height: 4.0),
            Text(
              context.drillL10n.estimatedTime(minutes),
              textAlign: .center,
              style: subtitleStyle,
            ),
          ],
          const SizedBox(height: 16.0),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_nbPuzzles),
            child: Text(widget.actionLabel?.call(_nbPuzzles) ?? context.drillL10n.done),
          ),
        ],
      ),
    );
  }
}
