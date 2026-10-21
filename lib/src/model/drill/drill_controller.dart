import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lichess_mobile/src/binding.dart';
import 'package:lichess_mobile/src/model/auth/auth_controller.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_angle.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_batch_storage.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_controller.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_difficulty.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_preferences.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_theme.dart';
import 'package:lichess_mobile/src/model/settings/preferences_storage.dart';
import 'package:lichess_mobile/src/model/user/user.dart';
import 'package:lichess_mobile/src/service/puzzle_service.dart';
import 'package:logging/logging.dart';

part 'drill_controller.freezed.dart';
part 'drill_controller.g.dart';

final _logger = Logger('DrillController');

/// The Drill being played, or `null` when there is none.
final drillControllerProvider = NotifierProvider<DrillController, DrillState?>(
  DrillController.new,
  name: 'DrillControllerProvider',
);

/// Owns the lifecycle of a Drill: starts it, records the outcome of each puzzle, ends it, and
/// resumes it after the app restarts.
///
/// Puzzles are solved by the [PuzzleController] of [DrillState.puzzleContext], which applies the
/// official result rules and sends the solutions through the [PuzzleService]. The Drill counts
/// and records on top of it. Until it is over, the Drill is kept as the unfinished Drill of the
/// player's account ([unfinishedDrillProvider]).
class DrillController() extends Notifier<DrillState?> {
  ProviderSubscription<PuzzleState>? _puzzleSubscription;
  _SolvingClock? _solvingClock;

  /// Whether the puzzle controller is done with the last result: its solution saved and sent to
  /// the server, or kept pending if it could not be sent.
  bool _isLastResultSaved = true;

  @override
  DrillState? build() {
    ref.onDispose(() => _solvingClock?.dispose());
    listenSelf((previous, next) {
      // Without a Drill anymore, it was discarded or left to its account: see [_discard].
      final userId = next?.puzzleContext.userId;
      if (next == null || userId == null) return;
      final unfinishedDrill = ref.read(unfinishedDrillProvider.notifier);
      if (!next.isOver) {
        if (next.drill != previous?.drill) unfinishedDrill.save(userId, next.drill);
      } else if (previous != null && !previous.isOver) {
        unfinishedDrill.clear(userId);
      }
    });
    // The Drill being played stays the unfinished Drill of its account, to be resumed once signed
    // in with it again.
    ref.listen(authControllerProvider.select((auth) => auth?.user.id), (_, _) => _leave());
    return null;
  }

  /// Starts a new Drill with [config], replacing the current one if any.
  ///
  /// The unfinished Drill replaced ends as a Partial Drill.
  ///
  /// Returns `false` if no puzzle could be loaded.
  Future<bool> start(DrillConfig config) async {
    final puzzleContext = await _loadPuzzle(config);
    if (puzzleContext == null) return false;

    await ref.read(lastDrillConfigProvider.notifier).save(config);
    _play(
      Drill(
        config: config,
        startedAt: clock.now(),
        ratingBefore: puzzleContext.glicko?.rating.round(),
      ),
      puzzleContext,
    );
    return true;
  }

  /// Resumes the unfinished Drill: the one being played, or the [unfinishedDrillProvider] after the
  /// app restarted or the player signed in again.
  ///
  /// Returns `false` if there is no Drill to resume or no puzzle could be loaded.
  Future<bool> resume() async {
    if (state case DrillState(isOver: false)) return true;
    final drill = ref.read(unfinishedDrillProvider);
    if (drill == null) return false;

    final puzzleContext = await _loadPuzzle(drill.config);
    if (puzzleContext == null) return false;
    _play(drill, puzzleContext);
    // Loading the puzzle synced the solutions left pending.
    _onSync(rounds: puzzleContext.rounds, glicko: puzzleContext.glicko);
    // The app was closed after the last result, before the player moved on.
    if (drill.isLimitReached) _end();
    return true;
  }

  /// Ends the Drill now. It is a Partial Drill if it ended before its last puzzle, or discarded if
  /// no puzzle was solved: then there is no Drill anymore.
  ///
  /// The puzzle being solved, if it has no result yet, is left out. Returns whether the Drill has
  /// a Drill Summary to show, `false` if it was discarded.
  bool end() {
    final drillState = state;
    if (drillState == null) return false;
    if (drillState.isOver) return true;
    if (drillState.drill.results.isEmpty) {
      _discard();
      return false;
    }
    _end();
    return true;
  }

  /// Moves on from the solved puzzle: to the next one, or to the end of the Drill after the last.
  void continueDrill() {
    final drillState = state;
    if (drillState == null || drillState.isOver) return;

    if (drillState.drill.isLimitReached) {
      _end();
      return;
    }
    final puzzleCtrlProvider = puzzleControllerProvider(drillState.puzzleContext);
    final nextContext = ref.read(puzzleCtrlProvider).nextContext;
    if (nextContext != null) {
      ref.read(puzzleCtrlProvider.notifier).onLoadPuzzle(nextContext);
    }
  }

  /// Drops the Drill being played without ending it, and forgets it.
  void _discard() {
    final userId = state?.puzzleContext.userId;
    if (userId != null) ref.read(unfinishedDrillProvider.notifier).clear(userId);
    _leave();
  }

  /// Drops the Drill being played without ending it: if unfinished, it stays the unfinished Drill
  /// of its account.
  void _leave() {
    _puzzleSubscription?.close();
    _puzzleSubscription = null;
    state = null;
  }

  /// Loads the puzzle to play a Drill with [config] on.
  Future<PuzzleContext?> _loadPuzzle(DrillConfig config) async {
    final userId = ref.read(authControllerProvider)?.user.id;
    final puzzlePrefs = ref.read(puzzlePreferencesProvider);
    final service = await _puzzleService(config.angle);
    // The puzzle service and controller fetch puzzles at the difficulty of the preferences, which
    // Drills don't expose otherwise. The puzzles queued at another difficulty are dropped, as when
    // the difficulty is changed in the official app.
    if (puzzlePrefs.difficulty != config.difficulty) {
      await ref.read(puzzlePreferencesProvider.notifier).setDifficulty(config.difficulty);
      await service.deleteBatch(userId: userId, angle: config.angle);
    }
    return await service.nextPuzzle(userId: userId, angle: config.angle);
  }

  /// Plays [drill] from its next puzzle, loaded in [puzzleContext].
  void _play(Drill drill, PuzzleContext puzzleContext) {
    _puzzleSubscription?.close();
    (_solvingClock ??= _SolvingClock()).stop();
    _isLastResultSaved = true;
    state = DrillState(
      drill: drill,
      puzzleContext: puzzleContext,
      puzzleNumber: drill.results.length + 1,
    );
    _puzzleSubscription = ref.listen(puzzleControllerProvider(puzzleContext), _onPuzzleStateChange);
  }

  Future<PuzzleService> _puzzleService(PuzzleAngle angle) => ref.read(puzzleServiceFactoryProvider)(
    queueLength: offlineQueueLengthForAngle(
      angle,
      ref.read(puzzlePreferencesProvider).nbOfflinePuzzles,
    ),
  );

  void _onPuzzleStateChange(PuzzleState? previous, PuzzleState next) {
    final nextContext = next.nextContext;
    if (nextContext != null && nextContext != previous?.nextContext) {
      // The puzzle controller saved the last result and tried to send it: it prepares the next
      // puzzle with what the server returned.
      _isLastResultSaved = true;
      _onSync(rounds: nextContext.rounds, glicko: nextContext.glicko);
      if (state?.isOver == true) {
        _sendPendingSolutions();
        return;
      }
    }

    final drillState = state;
    if (drillState == null || drillState.isOver) return;
    final drill = drillState.drill;
    final solvingClock = _solvingClock!;

    if (next.result == null && next.mode == .play && !solvingClock.isRunning) {
      solvingClock.start();
    }

    final puzzleId = next.puzzle.puzzle.id;
    final result = next.result;
    if (previous != null && previous.puzzle.puzzle.id != puzzleId) {
      // The next puzzle was loaded, by [continueDrill] or by the puzzle controller itself when
      // auto-next is on.
      if (drill.isLimitReached) {
        _end();
      } else {
        // Counted from the results rather than incremented: a puzzle whose solution was not saved
        // before the app was killed is loaded again when the Drill is resumed.
        state = drillState.copyWith(puzzleNumber: drill.results.length + 1);
      }
    } else if (result != null && drill.results.lastOrNull?.id != puzzleId) {
      _isLastResultSaved = false;
      final solvingTime = solvingClock.stop();
      final puzzle = next.puzzle.puzzle;
      state = drillState.copyWith(
        drill: drill.copyWith(
          results: drill.results.add(
            DrillPuzzleResult(
              id: puzzleId,
              puzzleRating: puzzle.rating,
              themes: puzzle.themes,
              win: result == .win,
              // The rule of the puzzle controller, which sends the solution.
              rated:
                  drillState.puzzleContext.userId != null &&
                  !next.hintShown &&
                  ref.read(puzzlePreferencesProvider).rated,
              solvingTime: solvingTime,
            ),
          ),
        ),
      );
    } else if (drill.ratingBefore == null && drill.latestRating == null && next.glicko != null) {
      // The puzzle controller reads the player's rating when it starts, if the first puzzle
      // didn't come with it. It is the rating before the Drill unless a solution of the Drill was
      // sent first.
      state = drillState.copyWith(drill: drill.copyWith(ratingBefore: next.glicko!.rating.round()));
    }
  }

  /// Records what a sync of the solutions with the server returned: the rating change of each
  /// solution sent and the player's new rating.
  void _onSync({required IList<PuzzleRound>? rounds, required PuzzleGlicko? glicko}) {
    final drillState = state;
    if (drillState == null) return;
    final drill = drillState.drill;
    final ratingDiffs = {
      for (final round in rounds ?? const <PuzzleRound>[]) round.id: round.ratingDiff,
    };
    state = drillState.copyWith(
      drill: drill.copyWith(
        results: drill.results
            .map(
              (r) => r.rated && ratingDiffs.containsKey(r.id)
                  ? r.copyWith(ratingDiff: ratingDiffs[r.id])
                  : r,
            )
            .toIList(),
        latestRating: glicko?.rating.round() ?? drill.latestRating,
      ),
    );
  }

  /// Ends the Drill, then sends its pending solutions to the server, once the puzzle controller is
  /// done with the last result.
  void _end() {
    state = state?.copyWith(isOver: true);
    if (_isLastResultSaved) _sendPendingSolutions();
  }

  /// Sends the solutions that could not be sent yet, so that the Drill Summary gets their rating
  /// changes as soon as possible.
  ///
  /// The puzzle controller sends each solution as soon as its puzzle is solved, but keeps it
  /// pending when that fails: offline, or while the server limits the solving rate (the puzzle
  /// service then doesn't try again).
  Future<void> _sendPendingSolutions() async {
    _puzzleSubscription?.close();
    _puzzleSubscription = null;
    final drill = state;
    if (drill == null) return;

    final userId = drill.puzzleContext.userId;
    final angle = drill.drill.config.angle;
    try {
      final batchStorage = await ref.read(puzzleBatchStorageProvider.future);
      final batch = await batchStorage.fetch(userId: userId, angle: angle);
      if (batch == null || batch.solved.isEmpty || !ref.mounted) return;
      final synced = await (await _puzzleService(angle)).nextPuzzle(userId: userId, angle: angle);
      // Another Drill may have started meanwhile.
      if (synced != null && ref.mounted && state?.puzzleContext == drill.puzzleContext) {
        _onSync(rounds: synced.rounds, glicko: synced.glicko);
      }
    } catch (e, st) {
      // The solutions stay pending, as when they can't be sent.
      _logger.warning('Failed to send the pending solutions', e, st);
    }
  }
}

/// Times the puzzle being solved: from when the player can move to its result, only while the app
/// is shown.
class _SolvingClock() {
  this {
    _isAppHidden = switch (WidgetsBinding.instance.lifecycleState) {
      .hidden || .paused || .detached => true,
      _ => false,
    };
    _appLifecycleListener = AppLifecycleListener(
      onHide: () => _setAppHidden(true),
      onShow: () => _setAppHidden(false),
    );
  }

  late final AppLifecycleListener _appLifecycleListener;
  late bool _isAppHidden;

  bool _isRunning = false;

  /// The time spent on the puzzle, up to [_runningSince].
  Duration _elapsed = Duration.zero;

  /// Since when the time has been running, or `null` while it doesn't.
  DateTime? _runningSince;

  /// Whether a puzzle is being timed, even while the app is hidden.
  bool get isRunning => _isRunning;

  /// Starts timing a new puzzle.
  void start() {
    _isRunning = true;
    _elapsed = Duration.zero;
    _update();
  }

  /// Stops timing the puzzle and returns the time spent on it.
  Duration stop() {
    _isRunning = false;
    _update();
    return _elapsed;
  }

  void dispose() => _appLifecycleListener.dispose();

  void _setAppHidden(bool isHidden) {
    _isAppHidden = isHidden;
    _update();
  }

  void _update() {
    final shouldRun = _isRunning && !_isAppHidden;
    final since = _runningSince;
    if (since != null && !shouldRun) {
      _elapsed += clock.now().difference(since);
      _runningSince = null;
    } else if (since == null && shouldRun) {
      _runningSince = clock.now();
    }
  }
}

/// The configuration of the last Drill started with the signed in account, preselected to set up
/// the next one.
final lastDrillConfigProvider = NotifierProvider<LastDrillConfig, DrillConfig>(
  LastDrillConfig.new,
  name: 'LastDrillConfigProvider',
);

class LastDrillConfig() extends Notifier<DrillConfig> with SessionPreferencesStorage<DrillConfig> {
  @override
  @protected
  final prefCategory = PrefCategory.drill;

  @override
  DrillConfig defaults({LightUser? user}) => const DrillConfig(nbPuzzles: 10);

  @override
  DrillConfig fromJson(Map<String, dynamic> json) => DrillConfig.fromJson(json);

  @override
  DrillConfig build() {
    final config = fetch();
    // Edited or corrupted prefs could hold a number of puzzles the setup screen doesn't allow.
    final nbPuzzles = config.nbPuzzles.clamp(1, kMaxDrillPuzzles);
    return nbPuzzles == config.nbPuzzles ? config : config.copyWith(nbPuzzles: nbPuzzles);
  }
}

/// The unfinished Drill of the signed in player, kept on the device so that it can be resumed after
/// the app is closed or killed, or `null` when there is none.
///
/// Each account has its own, kept while signed out. The [DrillController] keeps them up to date.
final unfinishedDrillProvider = NotifierProvider<UnfinishedDrill, Drill?>(
  UnfinishedDrill.new,
  name: 'UnfinishedDrillProvider',
);

class UnfinishedDrill() extends Notifier<Drill?> {
  static String _storageKey(UserId userId) => 'drill.unfinished.$userId';

  @override
  Drill? build() {
    final userId = ref.watch(authControllerProvider.select((auth) => auth?.user.id));
    if (userId == null) return null;
    final stored = LichessBinding.instance.sharedPreferences.getString(_storageKey(userId));
    if (stored == null) return null;
    try {
      return Drill.fromJson(jsonDecode(stored) as Map<String, dynamic>);
    } catch (e, st) {
      _logger.warning('Failed to decode the unfinished Drill', e, st);
      clear(userId);
      return null;
    }
  }

  /// Keeps [drill] as the unfinished Drill of the account [userId].
  Future<void> save(UserId userId, Drill drill) async {
    if (userId == _signedInUserId) state = drill;
    await LichessBinding.instance.sharedPreferences.setString(
      _storageKey(userId),
      jsonEncode(drill.toJson()),
    );
  }

  /// Forgets the unfinished Drill of the account [userId].
  Future<void> clear(UserId userId) async {
    if (userId == _signedInUserId) state = null;
    await LichessBinding.instance.sharedPreferences.remove(_storageKey(userId));
  }

  UserId? get _signedInUserId => ref.read(authControllerProvider)?.user.id;
}

/// The largest number of puzzles a Drill can have.
///
/// It is the most puzzles a batch request returns ([kServerPuzzleBatchCap]), so that a Drill's
/// puzzles can all be downloaded at once.
const kMaxDrillPuzzles = kServerPuzzleBatchCap;

/// The fewest puzzles for which a Drill's performance is reliable.
const kMinReliableDrillPuzzles = 6;

/// The most weakest themes a Drill Summary shows.
const kMaxWeakestThemes = 3;

/// The themes the Lichess puzzle dashboard leaves out of the weakest themes.
final _irrelevantThemes = {
  for (final key in [
    PuzzleThemeKey.oneMove,
    PuzzleThemeKey.short,
    PuzzleThemeKey.long,
    PuzzleThemeKey.veryLong,
    PuzzleThemeKey.mateIn1,
    PuzzleThemeKey.mateIn2,
    PuzzleThemeKey.mateIn3,
    PuzzleThemeKey.mateIn4,
    PuzzleThemeKey.mateIn5,
    PuzzleThemeKey.equality,
    PuzzleThemeKey.advantage,
    PuzzleThemeKey.crushing,
    PuzzleThemeKey.master,
    PuzzleThemeKey.masterVsMaster,
    PuzzleThemeKey.superGM,
  ])
    key.name,
};

/// How a Drill is configured when it starts.
@Freezed(fromJson: true, toJson: true)
sealed class DrillConfig with _$DrillConfig implements Serializable {
  const factory({
    /// The number of puzzles of the Drill, from 1 to [kMaxDrillPuzzles].
    required int nbPuzzles,

    /// The theme or opening of the puzzles.
    @Default(PuzzleTheme(PuzzleThemeKey.mix)) PuzzleAngle angle,
    @Default(PuzzleDifficulty.normal) PuzzleDifficulty difficulty,
  }) = _DrillConfig;

  factory fromJson(Map<String, dynamic> json) => _$DrillConfigFromJson(json);
}

/// The Drill being played: the [Drill] and the puzzle being solved.
@freezed
sealed class DrillState with _$DrillState {
  const factory({
    required Drill drill,

    /// The context of the [PuzzleController] solving the Drill's puzzles.
    ///
    /// It is the context of the first puzzle played: the same controller loads the following ones.
    required PuzzleContext puzzleContext,

    /// The number of the puzzle being solved, from 1.
    required int puzzleNumber,
    @Default(false) bool isOver,
  }) = _DrillState;
}

/// A Drill's configuration and the outcome of its puzzles, from which its Drill Summary is made.
@Freezed(fromJson: true, toJson: true)
sealed class const Drill._() with _$Drill implements Serializable {
  const factory({
    required DrillConfig config,
    required DateTime startedAt,

    /// The outcome of each puzzle solved, in order.
    @Default(IListConst<DrillPuzzleResult>([])) IList<DrillPuzzleResult> results,

    /// The player's puzzle rating when the Drill started, if known.
    int? ratingBefore,

    /// The player's puzzle rating returned by the latest sync of the solutions with the server.
    int? latestRating,
  }) = _Drill;

  factory fromJson(Map<String, dynamic> json) => _$DrillFromJson(json);

  /// Whether every puzzle of the Drill has been solved.
  bool get isLimitReached => results.length >= config.nbPuzzles;

  /// Whether the Drill, once ended, is a Partial Drill: it ended before its last puzzle.
  bool get isPartial => !isLimitReached;

  int get successes => results.where((r) => r.win).length;

  int get failures => results.length - successes;

  /// The share of puzzles solved, from 0 to 1, or 0 if no puzzle was solved.
  double get successRate => results.isEmpty ? 0 : successes / results.length;

  /// The time spent solving the Drill's puzzles.
  Duration get totalSolvingTime => results.fold(.zero, (total, r) => total + r.solvingTime);

  /// The average time spent solving a puzzle, or zero if no puzzle was solved.
  Duration get averageSolvingTime => results.isEmpty ? .zero : totalSolvingTime ~/ results.length;

  /// The rating level the Drill was played at, or `null` if no puzzle was solved.
  ///
  /// It is Lichess's puzzle performance: the average puzzle rating − 500 + 1000 × the share of
  /// puzzles solved. Every puzzle counts, rated or not, as on the Lichess puzzle dashboard.
  int? get performance {
    if (results.isEmpty) return null;
    final averageRating = results.map((r) => r.puzzleRating).average;
    return (averageRating - 500 + 1000 * successRate).round();
  }

  /// Whether there are enough puzzles for the [performance] to mean something.
  bool get isPerformanceReliable => results.length >= kMinReliableDrillPuzzles;

  /// The themes most frequent among the failed puzzles, most failed first, at most
  /// [kMaxWeakestThemes] of them.
  ///
  /// As on the Lichess puzzle dashboard, the themes describing a puzzle's length, the advantage
  /// it gives or its origin are left out: they say nothing about the tactics missed.
  IList<({String theme, int failures})> get weakestThemes {
    final failuresByTheme = <String, int>{};
    for (final result in results.where((r) => !r.win)) {
      for (final theme in result.themes.where((t) => !_irrelevantThemes.contains(t))) {
        failuresByTheme[theme] = (failuresByTheme[theme] ?? 0) + 1;
      }
    }
    // A stable sort: equally failed themes stay in the order they were first failed.
    final themes = failuresByTheme.entries.toList()
      ..sortByCompare((e) => e.value, (a, b) => b.compareTo(a));
    return themes.take(kMaxWeakestThemes).map((e) => (theme: e.key, failures: e.value)).toIList();
  }

  /// Whether a rated puzzle's rating change is not known yet, its solution not being synced.
  bool get hasPendingRatingDiff => results.any((r) => r.isRatingDiffPending);

  /// The player's puzzle rating once every result is synced, or `null` until then.
  int? get ratingAfter => hasPendingRatingDiff ? null : latestRating ?? ratingBefore;

  /// How much the Drill changed the player's rating, or `null` until it is known.
  int? get ratingChange {
    final before = ratingBefore;
    final after = ratingAfter;
    return before != null && after != null ? after - before : null;
  }
}

/// The outcome of a puzzle of a Drill.
@Freezed(fromJson: true, toJson: true)
sealed class const DrillPuzzleResult._() with _$DrillPuzzleResult {
  const factory({
    required PuzzleId id,
    required int puzzleRating,
    required ISet<String> themes,
    required bool win,

    /// Whether the result counts for the player's rating.
    required bool rated,

    /// The time spent solving the puzzle, between puzzles and in the background left out.
    required Duration solvingTime,

    /// How much the result changed the player's rating, once its solution is synced; always
    /// `null` when it is not [rated].
    int? ratingDiff,
  }) = _DrillPuzzleResult;

  factory fromJson(Map<String, dynamic> json) => _$DrillPuzzleResultFromJson(json);

  /// Whether the result is rated but its rating change is not known yet.
  bool get isRatingDiffPending => rated && ratingDiff == null;
}
