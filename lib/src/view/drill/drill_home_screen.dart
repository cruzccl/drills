import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lichess_mobile/src/model/auth/auth_controller.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/common/perf.dart';
import 'package:lichess_mobile/src/model/drill/drill_chart.dart';
import 'package:lichess_mobile/src/model/drill/drill_controller.dart';
import 'package:lichess_mobile/src/model/drill/drill_history.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_angle.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_difficulty.dart';
import 'package:lichess_mobile/src/model/settings/board_preferences.dart';
import 'package:lichess_mobile/src/model/user/user_repository_providers.dart';
import 'package:lichess_mobile/src/network/connectivity.dart';
import 'package:lichess_mobile/src/styles/lichess_icons.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/view/auth/sign_in_error.dart';
import 'package:lichess_mobile/src/view/auth/sign_in_options.dart';
import 'package:lichess_mobile/src/view/drill/drill_angle_screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_history_screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_profile_screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_progress_screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_settings_screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_strings.dart';
import 'package:lichess_mobile/src/view/drill/drill_summary.dart';
import 'package:lichess_mobile/src/view/puzzle/storm_screen.dart';
import 'package:lichess_mobile/src/widgets/adaptive_action_sheet.dart';
import 'package:lichess_mobile/src/widgets/adaptive_bottom_sheet.dart';
import 'package:lichess_mobile/src/widgets/buttons.dart';
import 'package:lichess_mobile/src/widgets/feedback.dart';
import 'package:lichess_mobile/src/widgets/non_linear_slider.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';
import 'package:lichess_mobile/src/widgets/platform_choice_chip.dart';
import 'package:lichess_mobile/src/widgets/platform_filled_button.dart';
import 'package:lichess_mobile/src/widgets/user.dart';
import 'package:material_ui/material_ui.dart';

/// The numbers of puzzles offered to set up a Drill with one tap.
const _quickPickNbPuzzles = [5, 10, 12, 15, 20, 25];

/// Every number of puzzles a Drill can have, along the slider.
final _sliderNbPuzzles = [for (var nb = 1; nb <= kMaxDrillPuzzles; nb++) nb];

/// How many of the latest Drills the home lists.
const _nbLastDrills = 3;

/// The screen the app opens on, where Drills are set up and started.
///
/// Signed in, it shows the player's streak of days in a row with a Drill, which opens their
/// progress, and their latest Drills, which open the Drill History. The next Drill is set up from
/// the configuration of the last Drill started, each of its settings changed on its own sheet or
/// screen. Signed out, Drills are played anonymously, and a notice offers to sign in: they count on
/// no account and are not kept.
class const DrillHomeScreen({super.key}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<DrillHomeScreen> createState() => _DrillHomeScreenState();
}

class _DrillHomeScreenState() extends ConsumerState<DrillHomeScreen> {
  bool _isStarting = false;
  late DrillConfig _config = ref.read(lastDrillConfigProvider);

  Future<void> _startDrill() async {
    setState(() => _isStarting = true);
    final started = await ref.read(drillControllerProvider.notifier).start(_config);
    if (!mounted) return;
    setState(() => _isStarting = false);
    if (started) {
      await _openDrill();
    } else {
      showSnackBar(context, DrillStrings.couldNotStartDrill, type: SnackBarType.error);
    }
  }

  Future<void> _resumeDrill() async {
    setState(() => _isStarting = true);
    final resumed = await ref.read(drillControllerProvider.notifier).resume();
    if (!mounted) return;
    setState(() => _isStarting = false);
    if (resumed) {
      await _openDrill();
    } else {
      showSnackBar(context, DrillStrings.couldNotStartDrill, type: SnackBarType.error);
    }
  }

  /// Opens the Drill being played, whose summary's weakest themes set up the next Drill.
  Future<void> _openDrill() => _setAngleFrom(Navigator.of(context).push(DrillScreen.buildRoute()));

  /// Opens the Drill History, whose summaries' weakest themes set up the Drill.
  Future<void> _openHistory() =>
      _setAngleFrom(Navigator.of(context).push(DrillHistoryScreen.buildRoute()));

  /// Opens the summary of a past Drill, whose weakest themes set up the Drill.
  Future<void> _openSummary(DrillHistoryEntry entry) => _setAngleFrom(
    Navigator.of(context).push(DrillHistorySummaryScreen.buildRoute(entry.startedAt)),
  );

  /// Opens the player's profile, whose dashboard themes set up the Drill.
  Future<void> _openProfile(UserId userId) =>
      _setAngleFrom(Navigator.of(context).push(DrillProfileScreen.buildRoute(userId)));

  /// Chooses the theme a screen returns, if any.
  Future<void> _setAngleFrom(Future<PuzzleAngle?> route) async {
    final angle = await route;
    if (angle != null && mounted) {
      setState(() => _config = _config.copyWith(angle: angle));
    }
  }

  Future<void> _chooseAngle() =>
      _setAngleFrom(Navigator.of(context).push(DrillAngleScreen.buildRoute(_config.angle)));

  Future<void> _chooseNbPuzzles(DrillConfig last) async {
    final nbPuzzles = await showAdaptiveBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _NbPuzzlesSheet(
        initial: _config.nbPuzzles,
        last: last.nbPuzzles,
        timePerPuzzle: _recentTimePerPuzzle(),
      ),
    );
    if (nbPuzzles != null && mounted) {
      setState(() => _config = _config.copyWith(nbPuzzles: nbPuzzles));
    }
  }

  Future<void> _chooseDifficulty(DrillConfig last, int? rating) async {
    final difficulty = await showAdaptiveBottomSheet<PuzzleDifficulty>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _DifficultySheet(initial: _config.difficulty, last: last.difficulty, rating: rating),
    );
    if (difficulty != null && mounted) {
      setState(() => _config = _config.copyWith(difficulty: difficulty));
    }
  }

  /// The average time the player spent on a puzzle in their latest Drills, if they were timed.
  Duration? _recentTimePerPuzzle() {
    final results = [
      for (final drill in ref.read(recentDrillsProvider).value ?? const IListConst<Drill>([]))
        for (final result in drill.results)
          if (result.solvingTime > Duration.zero) result,
    ];
    if (results.isEmpty) return null;
    return results.fold(Duration.zero, (total, r) => total + r.solvingTime) ~/ results.length;
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authControllerProvider);
    final isSignedIn = authUser != null;
    final isOnline = ref.watch(isDeviceOnlineProvider);
    final signInState = ref.watch(signInMutation);
    final unfinishedDrill = ref.watch(unfinishedDrillProvider);
    final last = ref.watch(lastDrillConfigProvider);
    final user = authUser != null ? ref.watch(userProvider(authUser.user.id)).value : null;
    final entries = isSignedIn
        ? ref.watch(drillHistoryProvider).value?.entries ?? const IListConst([])
        : const IListConst<DrillHistoryEntry>([]);
    final points = isSignedIn ? ref.watch(drillChartPointsProvider).value : null;
    final weakThemes =
        ref.watch(recentWeakestThemesProvider).value ?? const IListConst<DrillWeakTheme>([]);
    // Kept alive for the pace of the number of puzzles sheet.
    ref.watch(recentDrillsProvider);
    final rating = user?.perfs[Perf.puzzle]?.rating ?? entries.firstOrNull?.ratingAfter;
    final angle = _config.angle;
    final isWeakTheme =
        angle is PuzzleTheme && weakThemes.any((t) => t.theme == angle.themeKey.name);

    ref.listen(signInMutation, (_, next) => showSignInErrorSnackBar(context, next));

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text(DrillStrings.appName),
        actions: [
          SemanticIconButton(
            icon: const Icon(Icons.settings_outlined),
            semanticsLabel: context.l10n.settingsSettings,
            onPressed: () => Navigator.of(context).push(DrillSettingsScreen.buildRoute()),
          ),
          if (authUser != null)
            SemanticIconButton(
              // The profile's user has the flair, which the signed in user lacks.
              icon: UserAvatar(user?.lightUser ?? authUser.user, radius: 14),
              semanticsLabel: DrillStrings.profile,
              onPressed: () => _openProfile(authUser.user.id),
            ),
        ],
      ),
      // The body's own context: the padding of the screen's isn't the one inside the scaffold.
      body: Builder(
        builder: (context) => ListView(
          padding: Styles.bodyPadding.add(MediaQuery.paddingOf(context)),
          children: [
            if (!isSignedIn) ...[
              Text(DrillStrings.signedOutNotice, style: TextTheme.of(context).bodyLarge),
              const SizedBox(height: 12.0),
              OutlinedButton(
                onPressed: isOnline && signInState is! MutationPending
                    ? () => showSignInOptions(context, ref)
                    : null,
                child: Text(context.l10n.signIn),
              ),
              const SizedBox(height: 24.0),
            ],
            if (points != null) ...[
              _StreakCard(
                points: points,
                today: DateTime.now(),
                onOpenProgress: points.isEmpty
                    ? null
                    : () => Navigator.of(context).push(DrillProgressScreen.buildRoute()),
              ),
              const SizedBox(height: 16.0),
            ],
            if (unfinishedDrill != null) ...[
              _UnfinishedDrillCard(unfinishedDrill, onTap: _isStarting ? null : _resumeDrill),
              const SizedBox(height: 16.0),
            ],
            _NextDrillCard(
              config: _config,
              last: last,
              isWeakTheme: isWeakTheme,
              isStarting: _isStarting,
              onNbPuzzles: () => _chooseNbPuzzles(last),
              onAngle: _chooseAngle,
              onDifficulty: () => _chooseDifficulty(last, rating),
              onReset: _config == last ? null : () => setState(() => _config = last),
              onStart: _isStarting
                  ? null
                  : unfinishedDrill != null
                  // A new Drill ends the unfinished one.
                  ? () => showConfirmDialog<void>(
                      context,
                      title: const Text(DrillStrings.replaceUnfinishedDrillConfirmation),
                      onConfirm: _startDrill,
                    )
                  : _startDrill,
              // A warm-up before the Drill: Puzzle Storm as in the official app, which counts
              // neither on the puzzle rating nor in the Drill.
              onWarmUp: isOnline
                  ? () => Navigator.of(context).push(StormScreen.buildRoute())
                  : null,
            ),
            if (entries.isNotEmpty) ...[
              const SizedBox(height: 20.0),
              _LastDrills(
                entries.take(_nbLastDrills),
                onSeeHistory: _openHistory,
                onOpen: _openSummary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The player's current streak of days in a row with a Drill and their best one, above the days
/// of this week, from Monday, those with a Drill lit.
class const _StreakCard({
  required final IList<DrillChartPoint> points,
  required final DateTime today,

  /// Opens the player's progress, `null` while they have no Drill.
  required final VoidCallback? onOpenProgress,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final streak = drillStreak(points, today: today);
    final played = drillPuzzlesByDay(points);
    final brag = context.lichessColors.brag;
    final subtitleStyle = TextStyle(
      fontSize: 13,
      color: textShade(context, Styles.subtitleOpacity),
    );
    final day = DateUtils.dateOnly(today);
    final monday = DateTime(day.year, day.month, day.day - (day.weekday - DateTime.monday));
    final weekdayFormat = DateFormat('EEEEE');
    return Card(
      margin: .zero,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20.0))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            Row(
              children: [
                Icon(Icons.local_fire_department, size: 40.0, color: brag),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text.rich(
                        TextSpan(
                          text: '${streak.current}',
                          style: const TextStyle(fontSize: 34, fontWeight: .bold, height: 1.1),
                          children: [
                            TextSpan(
                              text:
                                  ' ${streak.current == 1 ? DrillStrings.dayInARow : DrillStrings.daysInARow}',
                              style: const TextStyle(fontSize: 16, fontWeight: .normal),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${DrillStrings.bestStreak}: ${streak.best} '
                        '${streak.best == 1 ? DrillStrings.dayUnit : DrillStrings.daysUnit}',
                        style: subtitleStyle,
                      ),
                    ],
                  ),
                ),
                if (onOpenProgress != null)
                  TextButton(
                    onPressed: onOpenProgress,
                    child: const Row(
                      mainAxisSize: .min,
                      children: [Text(DrillStrings.progress), Icon(Icons.chevron_right, size: 18)],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14.0),
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  if (DateTime(monday.year, monday.month, monday.day + i) case final date)
                    Expanded(
                      child: Column(
                        spacing: 6.0,
                        children: [
                          Text(
                            weekdayFormat.format(date).toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: date == day ? .bold : .normal,
                              color: date == day ? null : subtitleStyle.color,
                            ),
                          ),
                          _StreakDay(
                            date,
                            played: played.containsKey(date),
                            isToday: date == day,
                            isFuture: date.isAfter(day),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
            if (!streak.playedToday) ...[
              const SizedBox(height: 12.0),
              Text(
                streak.current > 0
                    ? '${DrillStrings.playTodayToReach} ${streak.current + 1} '
                          '${DrillStrings.daysUnit}'
                    : DrillStrings.playTodayToStart,
                style: TextStyle(fontSize: 13, color: brag),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A day of the week of the streak: lit if [played], ringed if it is today.
class const _StreakDay(
  final DateTime date, {
  required final bool played,
  required final bool isToday,
  required final bool isFuture,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final brag = context.lichessColors.brag;
    final onSurface = ColorScheme.of(context).onSurface;
    final circle = Container(
      width: 30.0,
      height: 30.0,
      alignment: .center,
      decoration: BoxDecoration(
        shape: .circle,
        color: played
            ? brag
            : isFuture || isToday
            ? null
            : onSurface.withValues(alpha: 0.08),
      ),
      child: Text(
        '${date.day}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: played ? .bold : .normal,
          color: played
              ? Colors.black
              : isToday
              ? brag
              : textShade(context, isFuture ? 0.35 : Styles.subtitleOpacity),
        ),
      ),
    );
    return Container(
      width: 36.0,
      height: 36.0,
      alignment: .center,
      decoration: isToday
          ? BoxDecoration(
              shape: .circle,
              border: Border.all(color: brag, width: 2.0),
            )
          : null,
      child: circle,
    );
  }
}

/// The Drill left unfinished, with how far it went, which resumes it.
class const _UnfinishedDrillCard(final Drill drill, {required final VoidCallback? onTap})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brag = context.lichessColors.brag;
    final base = CardTheme.of(context).color ?? ColorScheme.of(context).surfaceContainerLow;
    return Card(
      margin: .zero,
      clipBehavior: .antiAlias,
      color: Color.alphaBlend(brag.withValues(alpha: 0.14), base),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16.0))),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          child: Row(
            spacing: 12.0,
            children: [
              CircleAvatar(
                radius: 20.0,
                backgroundColor: brag,
                child: const Icon(Icons.play_arrow, color: Colors.black),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: .stretch,
                  spacing: 4.0,
                  children: [
                    const Text(
                      DrillStrings.resumeDrill,
                      style: TextStyle(fontSize: 15, fontWeight: .w600),
                    ),
                    Text(
                      [
                        '${drill.results.length} / ${drill.config.nbPuzzles}',
                        drillAngleName(context, ref, drill.config.angle),
                        puzzleDifficultyL10n(context, drill.config.difficulty),
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 12,
                        color: textShade(context, Styles.subtitleOpacity),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(2.0)),
                      child: LinearProgressIndicator(
                        value: drill.results.length / drill.config.nbPuzzles,
                        minHeight: 4.0,
                        color: brag,
                        backgroundColor: brag.withValues(alpha: 0.25),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The next Drill: its number of puzzles, theme and difficulty, each changed on its own sheet or
/// screen and outlined when it differs from the last Drill started, then the buttons to start it
/// and to warm up before.
class const _NextDrillCard({
  required final DrillConfig config,

  /// The configuration of the last Drill started.
  required final DrillConfig last,

  /// Whether the theme is one of the themes to work on.
  required final bool isWeakTheme,
  required final bool isStarting,
  required final VoidCallback onNbPuzzles,
  required final VoidCallback onAngle,
  required final VoidCallback onDifficulty,

  /// Sets the configuration of the last Drill back, `null` when it is the one set.
  required final VoidCallback? onReset,
  required final VoidCallback? onStart,
  required final VoidCallback? onWarmUp,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = ColorScheme.of(context);
    final primary = context.lichessColors.primary;
    final base = CardTheme.of(context).color ?? colorScheme.surfaceContainerLow;
    final cardColor = Color.alphaBlend(primary.withValues(alpha: 0.10), base);
    final tileColor = Color.alphaBlend(primary.withValues(alpha: 0.12), cardColor);
    final subtitleColor = textShade(context, Styles.subtitleOpacity);
    final nbPuzzlesChanged = config.nbPuzzles != last.nbPuzzles;
    return Card(
      margin: .zero,
      color: cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20.0))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            SizedBox(
              height: 40.0,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      DrillStrings.nextDrill.toUpperCase(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: .w600,
                        letterSpacing: 0.4,
                        color: primary,
                      ),
                    ),
                  ),
                  if (onReset != null)
                    TextButton.icon(
                      onPressed: onReset,
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: const Text(DrillStrings.sameAsLast),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4.0),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: .stretch,
                spacing: 8.0,
                children: [
                  _ConfigTile(
                    label: DrillStrings.nbPuzzlesTile,
                    color: tileColor,
                    changed: nbPuzzlesChanged,
                    onTap: onNbPuzzles,
                    value: Text(
                      '${config.nbPuzzles}',
                      style: const TextStyle(fontSize: 22, fontWeight: .bold),
                    ),
                    detail: nbPuzzlesChanged
                        ? Text(
                            '${last.nbPuzzles}',
                            style: TextStyle(
                              fontSize: 12,
                              color: subtitleColor,
                              decoration: TextDecoration.lineThrough,
                            ),
                          )
                        : null,
                  ),
                  _ConfigTile(
                    label: DrillStrings.theme,
                    color: tileColor,
                    changed: config.angle != last.angle,
                    onTap: onAngle,
                    value: Text(
                      drillAngleName(context, ref, config.angle),
                      maxLines: 2,
                      overflow: .ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: .w600, height: 1.2),
                    ),
                    detail: isWeakTheme
                        ? Row(
                            spacing: 4.0,
                            children: [
                              Container(
                                width: 6.0,
                                height: 6.0,
                                decoration: BoxDecoration(
                                  shape: .circle,
                                  color: context.lichessColors.error,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  DrillStrings.toWorkOnTag,
                                  overflow: .ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.lichessColors.error,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                  _ConfigTile(
                    label: DrillStrings.difficulty,
                    color: tileColor,
                    changed: config.difficulty != last.difficulty,
                    onTap: onDifficulty,
                    value: Text(
                      puzzleDifficultyL10n(context, config.difficulty),
                      maxLines: 2,
                      overflow: .ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: .w600, height: 1.2),
                    ),
                    detail: DrillDifficultyDots(config.difficulty),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14.0),
            PlatformFilledButton(
              onPressed: onStart,
              child: isStarting
                  ? const ButtonLoadingIndicator()
                  : const Row(
                      mainAxisSize: .min,
                      spacing: 6.0,
                      children: [Icon(Icons.play_arrow), Text(DrillStrings.startDrill)],
                    ),
            ),
            TextButton.icon(
              icon: const Icon(LichessIcons.storm, size: 18),
              label: const Text(DrillStrings.warmUpWithStorm),
              style: TextButton.styleFrom(foregroundColor: context.lichessColors.brag),
              onPressed: onWarmUp,
            ),
          ],
        ),
      ),
    );
  }
}

/// A setting of the next Drill: its name, value and details, which changes it.
class const _ConfigTile({
  required final String label,
  required final Widget value,
  final Widget? detail,
  required final Color color,

  /// Whether it differs from the last Drill's.
  required final bool changed,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final primary = context.lichessColors.primary;
    return Expanded(
      child: Material(
        color: color,
        clipBehavior: .antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14.0)),
          side: changed ? BorderSide(color: primary, width: 1.5) : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64.0),
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: .start,
                spacing: 3.0,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: primary)),
                  value,
                  ?detail,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The latest Drills, a line each, which open their summaries, and a link to the Drill History.
class const _LastDrills(
  final Iterable<DrillHistoryEntry> entries, {
  required final VoidCallback onSeeHistory,
  required final void Function(DrillHistoryEntry entry) onOpen,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitleStyle = TextStyle(
      fontSize: 13,
      color: textShade(context, Styles.subtitleOpacity),
    );
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: 4.0),
                child: Text(DrillStrings.lastDrills, style: Styles.sectionTitle),
              ),
            ),
            TextButton(onPressed: onSeeHistory, child: const Text(DrillStrings.seeHistory)),
          ],
        ),
        Card(
          margin: .zero,
          clipBehavior: .antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16.0)),
          ),
          child: Column(
            children: [
              for (final (i, entry) in entries.indexed) ...[
                if (i > 0) const Divider(height: 1.0, indent: 14.0),
                InkWell(
                  onTap: () => onOpen(entry),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                    child: Column(
                      crossAxisAlignment: .stretch,
                      spacing: 8.0,
                      children: [
                        Row(
                          crossAxisAlignment: .baseline,
                          textBaseline: .alphabetic,
                          spacing: 8.0,
                          children: [
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  text: drillAngleName(context, ref, entry.config.angle),
                                  children: [
                                    TextSpan(
                                      text:
                                          ' · ${drillDayName(entry.startedAt, short: true)}, '
                                          '${DateFormat.Hm().format(entry.startedAt)}',
                                      style: subtitleStyle,
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: .ellipsis,
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                            Text('${entry.successes}/${entry.nbPlayed}', style: subtitleStyle),
                            SizedBox(
                              width: 36.0,
                              child: Text(
                                switch (entry.ratingChange) {
                                  final change? => formatRatingChange(change),
                                  null => '···',
                                },
                                textAlign: .end,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: .bold,
                                  color: switch (entry.ratingChange) {
                                    final change? => signColor(context, change),
                                    null => subtitleStyle.color,
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        DrillResultsBar(entry, height: 5.0),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Chooses the number of puzzles of the next Drill, which its route returns once done: one more
/// or less, a number offered, or any along the slider.
class const _NbPuzzlesSheet({
  required final int initial,

  /// The number of puzzles of the last Drill started.
  required final int last,

  /// The average time the player spends on a puzzle, to tell how long the Drill takes, if known.
  required final Duration? timePerPuzzle,
}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<_NbPuzzlesSheet> createState() => _NbPuzzlesSheetState();
}

class _NbPuzzlesSheetState() extends ConsumerState<_NbPuzzlesSheet> {
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
              const Expanded(
                child: Text(
                  DrillStrings.nbPuzzlesChoice,
                  style: TextStyle(fontSize: 18, fontWeight: .w600),
                ),
              ),
              Text('${DrillStrings.lastOne}: ${widget.last}', style: subtitleStyle),
            ],
          ),
          const SizedBox(height: 16.0),
          Row(
            mainAxisAlignment: .center,
            spacing: 24.0,
            children: [
              IconButton.outlined(
                tooltip: DrillStrings.onePuzzleLess,
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
                    Text(DrillStrings.puzzlesUnit, style: subtitleStyle),
                  ],
                ),
              ),
              IconButton.outlined(
                tooltip: DrillStrings.onePuzzleMore,
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
              '${DrillStrings.approximately} $minutes '
              '${minutes == 1 ? DrillStrings.minuteUnit : DrillStrings.minutesUnit}, '
              '${DrillStrings.atYourPace}',
              textAlign: .center,
              style: subtitleStyle,
            ),
          ],
          const SizedBox(height: 16.0),
          PlatformFilledButton(
            onPressed: () => Navigator.of(context).pop(_nbPuzzles),
            child: const Text(DrillStrings.done),
          ),
        ],
      ),
    );
  }
}

/// Chooses the difficulty of the next Drill, which its route returns once done, each with the
/// rating of its puzzles from the player's.
class const _DifficultySheet({
  required final PuzzleDifficulty initial,

  /// The difficulty of the last Drill started.
  required final PuzzleDifficulty last,

  /// The player's puzzle rating, if known.
  required final int? rating,
}) extends StatefulWidget {
  @override
  State<_DifficultySheet> createState() => _DifficultySheetState();
}

class _DifficultySheetState() extends State<_DifficultySheet> {
  late PuzzleDifficulty _difficulty = widget.initial;

  @override
  Widget build(BuildContext context) {
    final subtitleStyle = TextStyle(
      fontSize: 13,
      color: textShade(context, Styles.subtitleOpacity),
    );
    final rating = widget.rating;
    final primary = context.lichessColors.primary;
    final colorScheme = ColorScheme.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        spacing: 6.0,
        children: [
          Text(
            context.l10n.puzzleDifficultyLevel,
            style: const TextStyle(fontSize: 18, fontWeight: .w600),
          ),
          if (rating != null) Text('${DrillStrings.ratingBasis}, $rating', style: subtitleStyle),
          const SizedBox(height: 6.0),
          for (final difficulty in PuzzleDifficulty.values)
            Material(
              color: difficulty == _difficulty
                  ? primary.withValues(alpha: 0.15)
                  : colorScheme.surfaceContainerHighest,
              clipBehavior: .antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(Radius.circular(14.0)),
                side: difficulty == _difficulty
                    ? BorderSide(color: primary, width: 1.5)
                    : BorderSide.none,
              ),
              child: InkWell(
                onTap: () => setState(() => _difficulty = difficulty),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 58.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                    child: Row(
                      spacing: 12.0,
                      children: [
                        SizedBox(
                          width: 40.0,
                          child: Align(
                            alignment: .centerLeft,
                            child: DrillDifficultyDots(difficulty),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: .start,
                            spacing: 2.0,
                            children: [
                              Row(
                                spacing: 8.0,
                                children: [
                                  Flexible(
                                    child: Text(
                                      puzzleDifficultyL10n(context, difficulty),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                  if (difficulty == widget.last)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6.0,
                                        vertical: 1.0,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: colorScheme.outline),
                                        borderRadius: const BorderRadius.all(Radius.circular(8.0)),
                                      ),
                                      child: Text(
                                        DrillStrings.lastOneTag,
                                        style: subtitleStyle.copyWith(fontSize: 11),
                                      ),
                                    ),
                                ],
                              ),
                              if (rating != null)
                                Text(
                                  '${DrillStrings.puzzlesOfAbout} '
                                  '${((rating + difficulty.ratingDelta) / 50).round() * 50}'
                                  '${difficulty.ratingDelta == 0 ? ', ${DrillStrings.likeYou}' : ''}',
                                  style: subtitleStyle.copyWith(fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                        if (difficulty == _difficulty) Icon(Icons.check, color: primary),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10.0),
          PlatformFilledButton(
            onPressed: () => Navigator.of(context).pop(_difficulty),
            child: const Text(DrillStrings.done),
          ),
        ],
      ),
    );
  }
}
