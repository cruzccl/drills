import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/auth/auth_controller.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/common/perf.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_angle.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_providers.dart';
import 'package:lichess_mobile/src/model/user/user.dart';
import 'package:lichess_mobile/src/model/user/user_repository.dart';
import 'package:lichess_mobile/src/model/user/user_repository_providers.dart';
import 'package:lichess_mobile/src/styles/icon_extensions.dart';
import 'package:lichess_mobile/src/styles/lichess_colors.dart';
import 'package:lichess_mobile/src/styles/lichess_icons.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/utils/string.dart';
import 'package:lichess_mobile/src/view/drill/drill_history_screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_strings.dart';
import 'package:lichess_mobile/src/view/puzzle/dashboard_screen.dart';
import 'package:lichess_mobile/src/view/user/perf_stats_screen.dart';
import 'package:lichess_mobile/src/view/user/user_activity.dart';
import 'package:lichess_mobile/src/view/user/user_profile.dart';
import 'package:lichess_mobile/src/widgets/feedback.dart';
import 'package:lichess_mobile/src/widgets/haptic_refresh_indicator.dart';
import 'package:lichess_mobile/src/widgets/list.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';
import 'package:lichess_mobile/src/widgets/rating.dart';
import 'package:lichess_mobile/src/widgets/stat_card.dart';
import 'package:lichess_mobile/src/widgets/user.dart';
import 'package:material_ui/material_ui.dart';

final _activityProvider = FutureProvider.autoDispose.family<IList<UserActivity>, UserId>(
  (ref, id) => ref.read(userRepositoryProvider).getActivity(id),
  name: 'DrillProfileActivityProvider',
);

/// The player's Lichess profile, filtered to puzzles and Puzzle Storm: the profile card, the two
/// ratings, which open the puzzle and Puzzle Storm details, and the activity.
///
/// Its route returns the theme of the puzzle dashboard the player tapped, to set up a Drill with.
class const DrillProfileScreen({required final UserId userId, super.key}) extends ConsumerWidget {
  static Route<PuzzleAngle> buildRoute(UserId userId) {
    return buildScreenRoute(screen: DrillProfileScreen(userId: userId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider(userId));
    final lightUser = user.value?.lightUser ?? ref.watch(authControllerProvider)?.user;

    return PlatformScaffold(
      appBar: PlatformAppBar(
        // A long title, as on the official profile.
        centerTitle: false,
        titleSpacing: 0,
        title: lightUser == null
            ? null
            : Row(
                mainAxisSize: .min,
                children: [
                  UserAvatar(lightUser, radius: 16),
                  const SizedBox(width: 8),
                  Flexible(child: UserFullNameWidget(user: lightUser, showFlair: false)),
                ],
              ),
      ),
      body: switch (user) {
        AsyncData(:final value) => HapticRefreshIndicator(
          onRefresh: () => Future.wait([
            ref.refresh(userProvider(userId).future),
            ref.refresh(_activityProvider(userId).future),
          ]),
          // The body's own context: the padding of the screen's isn't the one inside the scaffold.
          child: Builder(
            // Not a lazy list: a section rebuilt on the way back would load its data again and
            // grow under the player's finger, pushing the sections below it.
            builder: (context) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 16.0).add(MediaQuery.paddingOf(context)),
              child: Column(
                crossAxisAlignment: .stretch,
                children: [
                  // The official profile card, without the games played.
                  UserProfileWidget(user: value.copyWith(count: null, playTime: null)),
                  _RatingCards(user: value),
                  _ActivitySection(userId: userId),
                ],
              ),
            ),
          ),
        ),
        AsyncError() => FullScreenRetryRequest(onRetry: () => ref.invalidate(userProvider(userId))),
        _ => const Center(child: CircularProgressIndicator.adaptive()),
      },
    );
  }
}

/// A section of the profile: a title above its content.
class const _Section({required final Widget title, required final List<Widget> children})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: Styles.horizontalBodyPadding.add(const EdgeInsets.only(top: 24.0)),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          DefaultTextStyle.merge(style: Styles.sectionTitle, child: title),
          const SizedBox(height: 8.0),
          ...children,
        ],
      ),
    );
  }
}

/// The puzzle and Puzzle Storm ratings, side by side, which open their details.
class const _RatingCards({required final User user}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final puzzle = user.perfs[Perf.puzzle];
    final storm = user.perfs[Perf.storm];
    if (puzzle == null && storm == null) return const SizedBox.shrink();
    return Padding(
      padding: Styles.horizontalBodyPadding.add(Styles.sectionTopPadding),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: .stretch,
          spacing: 8.0,
          children: [
            if (puzzle != null)
              Expanded(
                child: _RatingCard(
                  onTap: () async {
                    final angle = await Navigator.of(context)
                        .push(_PuzzlesScreen.buildRoute(user.id));
                    // A theme of the puzzle dashboard goes on back to the Drill home.
                    if (angle != null && context.mounted) Navigator.of(context).pop(angle);
                  },
                  label: DrillStrings.puzzles,
                  icon: Perf.puzzle.icon,
                  rating: RatingWidget(
                    rating: puzzle.rating,
                    deviation: puzzle.ratingDeviation,
                    provisional: puzzle.provisional,
                    style: const TextStyle(fontSize: 24, fontWeight: .w500),
                  ),
                  progression: puzzle.progression,
                  subtitle:
                      '${puzzle.numberOfGamesOrRuns.toString().localizeNumbers()} '
                      '${DrillStrings.played}',
                ),
              ),
            if (storm != null)
              Expanded(
                child: _RatingCard(
                  onTap: () => Navigator.of(context).push(_StormScreen.buildRoute(user.id)),
                  label: 'Puzzle Storm',
                  icon: Perf.storm.icon,
                  rating: Text(
                    '${storm.rating}',
                    style: const TextStyle(fontSize: 24, fontWeight: .w500),
                  ),
                  progression: 0,
                  subtitle:
                      '${DrillStrings.highScore} · ${storm.numberOfGamesOrRuns} '
                      '${storm.numberOfGamesOrRuns == 1 ? DrillStrings.run : DrillStrings.runs}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class const _RatingCard({
  required final VoidCallback onTap,
  required final String label,
  required final IconData icon,
  required final Widget rating,
  required final int progression,
  required final String subtitle,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final subtitleColor = textShade(context, Styles.subtitleOpacity);
    final progressionColor = progression > 0
        ? context.lichessColors.good
        : context.lichessColors.error;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: .antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: .start,
            spacing: 4.0,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(label, style: TextStyle(color: subtitleColor)),
                  ),
                  Icon(icon, size: 18, color: subtitleColor),
                ],
              ),
              Row(
                crossAxisAlignment: .baseline,
                textBaseline: .alphabetic,
                children: [
                  rating,
                  if (progression != 0) ...[
                    const SizedBox(width: 6),
                    Icon(
                      progression > 0
                          ? LichessIcons.arrow_full_upperright
                          : LichessIcons.arrow_full_lowerright,
                      color: progressionColor,
                      size: 12,
                    ),
                    Text(
                      progression.abs().toString(),
                      style: TextStyle(color: progressionColor, fontSize: 13),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(subtitle, style: TextStyle(color: subtitleColor, fontSize: 12)),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: subtitleColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The puzzle details: the rating history and the puzzle dashboard.
///
/// Its route returns the theme of the puzzle dashboard the player tapped.
class const _PuzzlesScreen({required final UserId userId}) extends ConsumerWidget {
  static Route<PuzzleAngle> buildRoute(UserId userId) {
    return buildScreenRoute(screen: _PuzzlesScreen(userId: userId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _DetailsScaffold(
      icon: Perf.puzzle.icon,
      title: DrillStrings.puzzles,
      onRefresh: () => Future.wait([
        ref.refresh(userRatingHistoryProvider(userId).future),
        ref.refresh(puzzleDashboardProvider(ref.read(daysProvider).days).future),
      ]),
      children: [
        _RatingHistorySection(userId: userId),
        const _DashboardSection(),
      ],
    );
  }
}

/// The Puzzle Storm details, as in the official app: the high scores and the best run of each day.
class const _StormScreen({required final UserId userId}) extends ConsumerWidget {
  static Route<void> buildRoute(UserId userId) {
    return buildScreenRoute(screen: _StormScreen(userId: userId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _DetailsScaffold(
      icon: Perf.storm.icon,
      title: 'Puzzle Storm',
      onRefresh: () => ref.refresh(stormDashboardProvider(userId).future),
      children: [_StormSection(userId: userId)],
    );
  }
}

/// A screen of details opened from a rating of the profile: its sections in a refreshable list.
class const _DetailsScaffold({
  required final IconData icon,
  required final String title,
  required final Future<void> Function() onRefresh,
  required final List<Widget> children,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Row(mainAxisSize: .min, spacing: 8.0, children: [Icon(icon, size: 20), Text(title)]),
      ),
      body: HapticRefreshIndicator(
        onRefresh: onRefresh,
        // The body's own context: the padding of the screen's isn't the one inside the scaffold.
        child: Builder(
          // Not a lazy list: a section rebuilt on the way back would load its data again and grow
          // under the player's finger, pushing the sections below it.
          builder: (context) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 16.0).add(MediaQuery.paddingOf(context)),
            child: Column(crossAxisAlignment: .stretch, children: children),
          ),
        ),
      ),
    );
  }
}

/// The puzzle rating history chart, with the highest and lowest puzzle ratings.
class const _RatingHistorySection({required final UserId userId}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratingHistory = ref.watch(userRatingHistoryProvider(userId));
    return switch (ratingHistory) {
      AsyncData(:final value) => () {
        final history = value.firstWhereOrNull((e) => e.perf == Perf.puzzle);
        if (history == null || history.points.length <= 1) return const SizedBox.shrink();
        final ratings = history.points.map((p) => p.elo);
        return _Section(
          title: const Text(DrillStrings.puzzleRating),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: RatingHistoryChart(history),
              ),
            ),
            const SizedBox(height: 8.0),
            StatCardRow([
              StatCard(DrillStrings.highestRating, value: '${ratings.max}'),
              StatCard(DrillStrings.lowestRating, value: '${ratings.min}'),
            ]),
          ],
        );
      }(),
      AsyncError() => const _Section(
        title: Text(DrillStrings.puzzleRating),
        children: [Text('Could not load the rating history.')],
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

/// The puzzle dashboard: global results over a number of days, then the improvement areas and
/// strengths, whose themes set up a Drill.
class const _DashboardSection() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(puzzleDashboardProvider(ref.watch(daysProvider).days));
    final title = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Text(context.l10n.puzzlePuzzleDashboard),
              Text(
                context.l10n.puzzlePuzzleDashboardDescription,
                style: Styles.subtitle.copyWith(
                  color: textShade(context, Styles.subtitleOpacity),
                  fontWeight: .normal,
                ),
              ),
            ],
          ),
        ),
        const DaysSelector(),
      ],
    );
    return switch (dashboard) {
      AsyncData(value: final dashboard?) when dashboard.global.nb > 0 => _Section(
        title: title,
        children: [
          StatCardRow([
            StatCard(context.l10n.performance, value: '${dashboard.global.performance}'),
            StatCard(
              context.l10n
                  .puzzleNbPlayed(dashboard.global.nb)
                  .replaceAll(RegExp(r'\d+'), '')
                  .trim()
                  .capitalize(),
              value: dashboard.global.nb.toString().localizeNumbers(),
            ),
            StatCard(
              context.l10n.puzzleSolved.capitalize(),
              value: '${(dashboard.global.firstWins / dashboard.global.nb * 100).round()}%',
            ),
          ]),
          for (final metric in [Metric.improvementArea, Metric.strength])
            if (metric.sort(dashboard.themes, dashboard) case final themes when themes.isNotEmpty)
              ListSection(
                margin: const EdgeInsets.only(top: 16.0),
                header: Text(metric.title(context.l10n)),
                children: [for (final data in themes) _ThemeRow(data: data, metric: metric)],
              ),
        ],
      ),
      AsyncError() => _Section(
        title: title,
        children: const [Text('Could not load the puzzle dashboard.')],
      ),
      AsyncData() => _Section(title: title, children: [Text(context.l10n.puzzleNoPuzzlesToShow)]),
      _ => const SizedBox.shrink(),
    };
  }
}

/// A theme of the puzzle dashboard, which goes back to the Drill home with that theme chosen.
class const _ThemeRow({required final PuzzleDashboardData data, required final Metric metric})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final solved = data.nb > 0 ? data.firstWins / data.nb : 0.0;
    final subtitleColor = textShade(context, Styles.subtitleOpacity);
    return ListTile(
      title: Text(data.theme.l10n(context.l10n).name),
      trailing: Row(
        mainAxisSize: .min,
        spacing: 12.0,
        children: [
          Text(data.nb.toString().localizeNumbers(), style: TextStyle(color: subtitleColor)),
          SizedBox(
            width: 60,
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(3)),
              child: LinearProgressIndicator(
                value: solved,
                minHeight: 6,
                color: metric == .strength
                    ? context.lichessColors.good
                    : context.lichessColors.error,
                backgroundColor: textShade(context, 0.15),
              ),
            ),
          ),
          SizedBox(width: 36, child: Text('${(solved * 100).round()}%', textAlign: .end)),
          const Icon(Icons.keyboard_arrow_right),
        ],
      ),
      onTap: () => Navigator.of(context).pop(PuzzleTheme(data.theme)),
    );
  }
}

/// The Puzzle Storm high scores, and the best run of each day Lichess keeps.
class const _StormSection({required final UserId userId}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(stormDashboardProvider(userId));
    final title = Text(context.l10n.stormHighscores);
    return switch (dashboard) {
      AsyncData(value: final dashboard?) => Column(
        crossAxisAlignment: .stretch,
        children: [
          _Section(
            title: title,
            children: [
              StatCardRow([
                StatCard(
                  context.l10n.stormAllTime,
                  value: '${dashboard.highScore.allTime}',
                  backgroundColor: LichessColors.brag.withValues(alpha: 0.5),
                ),
                StatCard(context.l10n.stormThisMonth, value: '${dashboard.highScore.month}'),
                StatCard(context.l10n.stormThisWeek, value: '${dashboard.highScore.week}'),
                StatCard(context.l10n.today, value: '${dashboard.highScore.day}'),
              ]),
            ],
          ),
          _Section(
            title: Text(context.l10n.stormBestRunOfDay),
            children: [
              if (dashboard.dayHighscores.isEmpty)
                Text(context.l10n.mobilePuzzleStormNothingToShow)
              else
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Table(
                      columnWidths: const {0: FlexColumnWidth(1.4)},
                      children: [
                        TableRow(
                          children: [
                            for (final (i, label) in [
                              '',
                              context.l10n.stormScore,
                              context.l10n.stormTime,
                              context.l10n.stormHighestSolved,
                              context.l10n.stormRuns,
                            ].indexed)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6.0),
                                child: Text(
                                  label,
                                  textAlign: i == 0 ? .start : .end,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textShade(context, Styles.subtitleOpacity),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        for (final day in dashboard.dayHighscores)
                          TableRow(
                            children: [
                              for (final (i, value) in [
                                drillDayName(day.day, short: true),
                                '${day.score}',
                                '${day.time}s',
                                '${day.highest}',
                                '${day.runs}',
                              ].indexed)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                                  child: Text(
                                    value,
                                    textAlign: i == 0 ? .start : .end,
                                    style: i == 1
                                        ? TextStyle(
                                            fontWeight: .bold,
                                            color: context.lichessColors.brag,
                                          )
                                        : null,
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      AsyncError() => _Section(
        title: title,
        children: const [Text('Could not load the Puzzle Storm dashboard.')],
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

/// The player's activity by day, puzzle and Puzzle Storm lines only.
class const _ActivitySection({required final UserId userId}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(_activityProvider(userId));
    final title = Text(context.l10n.activityActivity);
    return switch (activity) {
      AsyncData(:final value) => () {
        final days = value.where((e) => e.puzzles != null || e.storm != null).take(10);
        if (days.isEmpty) return const SizedBox.shrink();
        return _Section(
          title: title,
          children: [
            ListSection(
              margin: EdgeInsets.zero,
              hasLeading: true,
              children: [for (final day in days) _ActivityDay(day)],
            ),
          ],
        );
      }(),
      AsyncError() => _Section(
        title: title,
        children: const [Text('Could not load the activity.')],
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class const _ActivityDay(final UserActivity activity) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final puzzles = activity.puzzles;
    final storm = activity.storm;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 14.0, top: 16.0, right: 14.0, bottom: 4.0),
          child: Text(
            drillDayName(activity.startTime, short: true),
            style: TextStyle(color: context.lichessColors.brag, fontWeight: .bold),
          ),
        ),
        if (puzzles != null)
          ListTile(
            leading: Icon(Perf.puzzle.icon, size: 26),
            title: Text(context.l10n.activitySolvedNbPuzzles(puzzles.win + puzzles.loss)),
            subtitle: _RatingChange(before: puzzles.ratingBefore, after: puzzles.ratingAfter),
            trailing: BriefGameResultBox(win: puzzles.win, draw: 0, loss: puzzles.loss),
          ),
        if (storm != null)
          ListTile(
            leading: Icon(Perf.storm.icon, size: 26),
            title: Text(context.l10n.stormPlayedNbRunsOfPuzzleStorm(storm.runs, 'Puzzle Storm')),
            trailing: BriefGameResultBox(win: storm.score, draw: 0, loss: 0),
          ),
      ],
    );
  }
}

/// A rating after a day of puzzles, with its change over the day.
class const _RatingChange({required final int before, required final int after})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final diff = after - before;
    final color = diff > 0 ? context.lichessColors.good : context.lichessColors.error;
    return Row(
      children: [
        RatingWidget(deviation: 0, rating: after),
        if (diff != 0) ...[
          const SizedBox(width: 3),
          Icon(
            diff > 0 ? LichessIcons.arrow_full_upperright : LichessIcons.arrow_full_lowerright,
            color: color,
            size: 12,
          ),
          Text(diff.abs().toString(), style: TextStyle(color: color, fontSize: 11)),
        ],
      ],
    );
  }
}
