import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/drill/drill_chart.dart';
import 'package:lichess_mobile/src/model/drill/drill_group.dart';
import 'package:lichess_mobile/src/model/drill/drill_history.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_angle.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_difficulty.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/view/drill/drill_angle_screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_history_screen.dart';
import 'package:lichess_mobile/src/view/user/perf_stats_screen.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';
import 'package:material_ui/material_ui.dart';

/// The Drills of a range of days by theme and difficulty, opened from the Drill History, to pick
/// the ones to analyze together on one Drill Summary ([DrillGroup]).
///
/// The range is the last week, month, three months or year, the whole Drill History, or days the
/// player chooses. The groups of a single Drill are shown, disabled.
///
/// Its route returns the weakest theme of a Drill Summary the player tapped, to set up a Drill
/// with.
class const DrillGroupChoicesScreen({super.key}) extends ConsumerStatefulWidget {
  static Route<PuzzleAngle> buildRoute() {
    return buildScreenRoute(screen: const DrillGroupChoicesScreen());
  }

  @override
  ConsumerState<DrillGroupChoicesScreen> createState() => _DrillGroupChoicesScreenState();
}

class _DrillGroupChoicesScreenState() extends ConsumerState<DrillGroupChoicesScreen> {
  /// The range of days chosen among the ranges of the charts, `null` when the player chose the
  /// days ([_chosenDays]).
  DrillChartRange? _range = .month;

  DrillDays? _chosenDays;

  @override
  Widget build(BuildContext context) {
    final days = _chosenDays ?? drillDaysOf(_range!, today: DateTime.now());
    final choices = ref.watch(drillRangeGroupsProvider(days));
    final subtitleStyle = TextStyle(
      fontSize: 13,
      color: textShade(context, Styles.subtitleOpacity),
    );
    return PlatformScaffold(
      appBar: PlatformAppBar(title: Text(context.drillL10n.analyzeByDates)),
      // The body's own context: the padding of the screen's isn't the one inside the scaffold.
      body: Builder(
        builder: (context) => ListView(
          padding: Styles.bodyPadding.add(MediaQuery.paddingOf(context)),
          children: [
            Row(
              mainAxisAlignment: .spaceEvenly,
              children: [
                for (final range in DrillChartRange.values)
                  ChartRangeButton(
                    text: switch (range) {
                      .week => context.drillL10n.rangeWeek,
                      .month => context.drillL10n.rangeMonth,
                      .threeMonths => context.drillL10n.rangeThreeMonths,
                      .year => context.drillL10n.rangeYear,
                      .all => context.drillL10n.allDays,
                    },
                    selected: range == _range,
                    onPressed: () => setState(() {
                      _range = range;
                      _chosenDays = null;
                    }),
                  ),
              ],
            ),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(
                  days.first == null
                      ? context.drillL10n.chooseDates
                      : '${drillDayName(context, days.first!, short: true)} – '
                            '${drillDayName(context, days.last, short: true)}',
                ),
                onPressed: () => _chooseDays(days),
              ),
            ),
            switch (choices) {
              AsyncData(value: final choices) when choices.isEmpty => Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Center(child: Text(context.drillL10n.noDrillsInRange)),
              ),
              AsyncValue(value: final choices?) => Column(
                crossAxisAlignment: .stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0, right: 4.0, bottom: 10.0),
                    child: Text(
                      '${context.drillL10n.nbDrills(choices.map((c) => c.nbDrills).sum)} · '
                      '${context.drillL10n.nbPuzzles(choices.map((c) => c.nbPlayed).sum)}\n'
                      '${context.drillL10n.groupChoicesHint}',
                      style: subtitleStyle,
                    ),
                  ),
                  for (final choice in choices) ...[
                    _ChoiceCard(
                      choice,
                      onTap: choice.canBeAnalyzed ? () => _analyze(choice) : null,
                    ),
                    const SizedBox(height: 10.0),
                  ],
                ],
              ),
              AsyncError() => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32.0),
                child: Center(child: Text('Could not load the Drill History')),
              ),
              _ => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32.0),
                child: Center(child: CircularProgressIndicator.adaptive()),
              ),
            },
          ],
        ),
      ),
    );
  }

  /// Lets the player choose the days, starting from those shown.
  Future<void> _chooseDays(DrillDays days) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final first = days.first ?? DateTime(today.year, today.month, today.day - 29);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: today,
      initialDateRange: DateTimeRange(start: first.isAfter(today) ? today : first, end: days.last),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _range = null;
      _chosenDays = (first: DateUtils.dateOnly(picked.start), last: DateUtils.dateOnly(picked.end));
    });
  }

  /// Opens the Drill Summary of the Drills of [choice] taken as one, and returns the weakest theme
  /// tapped in it, if any.
  Future<void> _analyze(DrillGroupChoice choice) async {
    final angle = await Navigator.of(context)
        .push(DrillGroupSummaryScreen.buildRoute(choice.startedAts));
    if (angle != null && mounted) Navigator.of(context).pop(angle);
  }
}

/// The Drills of a theme and difficulty: how many, how many puzzles and the share solved.
///
/// Disabled, faded, when they can't be analyzed together ([onTap] is `null`).
class const _ChoiceCard(final DrillGroupChoice choice, {required final VoidCallback? onTap})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = choice.config;
    final subtitleStyle = TextStyle(
      fontSize: 13,
      color: textShade(context, Styles.subtitleOpacity),
    );
    return Opacity(
      opacity: onTap != null ? 1.0 : 0.45,
      child: Card(
        margin: .zero,
        clipBehavior: .antiAlias,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16.0))),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              spacing: 12.0,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    spacing: 4.0,
                    children: [
                      Text(
                        drillAngleName(context, ref, config.angle),
                        style: const TextStyle(fontSize: 17, fontWeight: .w500),
                        overflow: .ellipsis,
                      ),
                      Row(
                        spacing: 6.0,
                        children: [
                          Flexible(
                            child: Text(
                              puzzleDifficultyL10n(context, config.difficulty),
                              style: subtitleStyle,
                              overflow: .ellipsis,
                            ),
                          ),
                          DrillDifficultyDots(config.difficulty),
                        ],
                      ),
                      Text(
                        '${context.drillL10n.nbDrills(choice.nbDrills)} · '
                        '${context.drillL10n.nbPuzzles(choice.nbPlayed)}',
                        style: subtitleStyle,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(choice.successRate * 100).round()} %',
                  style: const TextStyle(fontSize: 22, fontWeight: .bold),
                ),
                if (onTap != null) Icon(Icons.chevron_right, color: subtitleStyle.color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
