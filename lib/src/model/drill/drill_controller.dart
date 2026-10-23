import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lichess_mobile/src/binding.dart';
import 'package:lichess_mobile/src/model/auth/auth_controller.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/drill/drill_history.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_angle.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_batch_storage.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_controller.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_difficulty.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_preferences.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_repository.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_theme.dart';
import 'package:lichess_mobile/src/model/settings/preferences_storage.dart';
import 'package:lichess_mobile/src/model/user/user.dart';
import 'package:lichess_mobile/src/network/connectivity.dart';
import 'package:lichess_mobile/src/network/http.dart';
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

/// How long to wait before trying again to send the pending solutions of an ended Drill.
final drillSendRetryDelayProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 30),
  name: 'DrillSendRetryDelayProvider',
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

  /// Whether the pending solutions are being sent by [_sendPendingSolutions].
  bool _isSendingPendingSolutions = false;

  /// Whether to try sending the pending solutions again once done, as asked meanwhile.
  bool _shouldRetrySendingPendingSolutions = false;

  /// Tries again later to send the pending solutions, see [_scheduleRetry].
  Timer? _retryTimer;

  @override
  DrillState? build() {
    // While the server limits the solving rate, the puzzle service doesn't send the pending
    // solutions: coming back to the app is a good time to check whether that is over.
    final appLifecycleListener = AppLifecycleListener(onResume: _retrySendingPendingSolutions);
    ref.onDispose(() {
      _retryTimer?.cancel();
      _solvingClock?.dispose();
      appLifecycleListener.dispose();
    });
    listenSelf((previous, next) {
      // Without a Drill anymore, it was discarded or left to its account: see [_discard].
      final userId = next?.puzzleContext.userId;
      if (next == null || userId == null) return;
      final unfinishedDrill = ref.read(unfinishedDrillProvider.notifier);
      if (!next.isOver) {
        if (next.drill != previous?.drill) unfinishedDrill.save(userId, next.drill);
        return;
      }
      if (previous != null && !previous.isOver) unfinishedDrill.clear(userId);
      // Once ended, the Drill is kept in the Drill History, with the rating changes as they come.
      final history = ref.read(drillHistoryProvider.notifier);
      if (previous?.isOver != true) {
        history.add(userId, next.drill);
      } else if (next.drill != previous?.drill) {
        history.replace(userId, next.drill);
      }
    });
    // The Drill being played stays the unfinished Drill of its account, to be resumed once signed
    // in with it again.
    ref.listen(authControllerProvider.select((auth) => auth?.user.id), (_, _) => _leave());
    // Solutions left pending offline are sent as soon as the device is back online.
    ref.listen(isDeviceOnlineProvider, (wasOnline, isOnline) {
      if (isOnline && wasOnline == false) _retrySendingPendingSolutions();
    });
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

    final userId = puzzleContext.userId;
    if (userId != null) {
      final history = ref.read(drillHistoryProvider.notifier);
      final replaced = ref.read(unfinishedDrillProvider);
      if (replaced != null && replaced.results.isNotEmpty) await history.add(userId, replaced);
      // Loading the puzzle synced the solutions left pending, maybe of the Drill replaced.
      await history.recordRatingDiffs(userId, puzzleContext.rounds);
    }
    await ref.read(lastDrillConfigProvider.notifier).save(config);
    _play(
      Drill(
        config: config,
        startedAt: clock.now(),
        // Signed out, a Drill counts on no account: it has no rating.
        ratingBefore: userId != null ? puzzleContext.glicko?.shownRating : null,
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
    _retryTimer?.cancel();
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
    // Drills don't expose otherwise.
    if (puzzlePrefs.difficulty != config.difficulty) {
      await ref.read(puzzlePreferencesProvider.notifier).setDifficulty(config.difficulty);
      await _requeue(userId: userId, angle: config.angle, difficulty: config.difficulty);
    }
    return await service.nextPuzzle(userId: userId, angle: config.angle);
  }

  /// Replaces the puzzles queued for [angle] with puzzles at [difficulty], keeping the solutions
  /// still to send.
  ///
  /// As when the difficulty is changed in the official app, the puzzles queued at another
  /// difficulty are dropped. The new ones are downloaded without sending the solutions, which the
  /// server may not take yet: the puzzle service sends them when it can.
  Future<void> _requeue({
    required UserId? userId,
    required PuzzleAngle angle,
    required PuzzleDifficulty difficulty,
  }) async {
    final batchStorage = await ref.read(puzzleBatchStorageProvider.future);
    IList<Puzzle> unsolved = const IListConst([]);
    try {
      final response = await ref.withClient(
        (client) =>
            PuzzleRepository(client)
                .selectBatch(nb: kMaxDrillPuzzles, angle: angle, difficulty: difficulty),
      );
      unsolved = response.puzzles;
    } catch (e, st) {
      // Without puzzles at that difficulty, no Drill can be started.
      _logger.warning('Failed to download the puzzles', e, st);
    }
    final batch = await batchStorage.fetch(userId: userId, angle: angle);
    await batchStorage.save(
      userId: userId,
      angle: angle,
      data: PuzzleBatch(solved: batch?.solved ?? const IListConst([]), unsolved: unsolved),
    );
  }

  /// Plays [drill] from its next puzzle, loaded in [puzzleContext].
  void _play(Drill drill, PuzzleContext puzzleContext) {
    _retryTimer?.cancel();
    _puzzleSubscription?.close();
    _solvingClock?.dispose();
    _solvingClock = _SolvingClock(_onSolvingTimeChange);
    _isLastResultSaved = true;
    state = DrillState(
      drill: drill,
      puzzleContext: puzzleContext,
      puzzleNumber: drill.results.length + 1,
    );
    _puzzleSubscription = ref.listen(puzzleControllerProvider(puzzleContext), _onPuzzleStateChange);
  }

  void _onSolvingTimeChange(DrillSolvingTime solvingTime) {
    final drillState = state;
    if (drillState == null || drillState.isOver || drillState.solvingTime == solvingTime) return;
    state = drillState.copyWith(solvingTime: solvingTime);
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

    if (state == null || state!.isOver) return;
    final solvingClock = _solvingClock!;
    if (next.result == null && next.mode == .play && !solvingClock.isRunning) {
      solvingClock.start();
    }
    // Read after starting the clock, which updates the state.
    final drillState = state!;
    final drill = drillState.drill;

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
      state = state!.copyWith(
        drill: drill.copyWith(
          results: drill.results.add(
            DrillPuzzleResult(
              id: puzzleId,
              puzzleRating: puzzle.rating,
              themes: puzzle.themes,
              win: result == .win,
              // The rule of the puzzle controller, which sends the solution.
              rated:
                  drillState.hasAccount &&
                  !next.hintShown &&
                  ref.read(puzzlePreferencesProvider).rated,
              solvingTime: solvingTime,
            ),
          ),
        ),
      );
    } else if (drillState.hasAccount &&
        drill.ratingBefore == null &&
        drill.latestRating == null &&
        next.glicko != null) {
      // The puzzle controller reads the player's rating when it starts, if the first puzzle
      // didn't come with it. It is the rating before the Drill unless a solution of the Drill was
      // sent first.
      state = drillState.copyWith(drill: drill.copyWith(ratingBefore: next.glicko!.shownRating));
    }
  }

  /// Records what a sync of the solutions with the server returned: the rating change of each
  /// solution sent and the player's new rating.
  void _onSync({required IList<PuzzleRound>? rounds, required PuzzleGlicko? glicko}) {
    final drillState = state;
    if (drillState == null) return;
    final drill = drillState.drill;
    state = drillState.copyWith(
      drill: drill
          .withRatingDiffs(rounds)
          .copyWith(latestRating: glicko?.shownRating ?? drill.latestRating),
    );
    // Solutions of previous Drills may have been sent along.
    final userId = drillState.puzzleContext.userId;
    if (userId != null) {
      ref
          .read(drillHistoryProvider.notifier)
          .recordRatingDiffs(userId, rounds, except: drill.startedAt);
    }
  }

  /// Ends the Drill, then sends its pending solutions to the server, once the puzzle controller is
  /// done with the last result.
  void _end() {
    state = state?.copyWith(isOver: true);
    if (_isLastResultSaved) _sendPendingSolutions();
  }

  /// Tries again to send the solutions of the ended Drill left pending, rated or not.
  ///
  /// While the Drill is played, the puzzle controller sends them with the next solution instead.
  Future<void> _retrySendingPendingSolutions() async {
    final drillState = state;
    if (drillState == null || !drillState.isOver || drillState.drill.results.isEmpty) return;
    if (!_isLastResultSaved) {
      // Without a puzzle left to play, the puzzle controller doesn't tell when it is done with
      // the last result: it is once the puzzle is no longer queued.
      final batchStorage = await ref.read(puzzleBatchStorageProvider.future);
      final batch = await batchStorage.fetch(
        userId: drillState.puzzleContext.userId,
        angle: drillState.drill.config.angle,
      );
      final lastId = drillState.drill.results.last.id;
      if (!ref.mounted || state != drillState) return;
      if (batch == null || batch.unsolved.any((p) => p.puzzle.id == lastId)) {
        _scheduleRetry();
        return;
      }
      _isLastResultSaved = true;
    }
    _sendPendingSolutions();
  }

  /// Tries again to send the pending solutions after [drillSendRetryDelayProvider], while the app
  /// is shown.
  ///
  /// The device coming back online is not always noticed: its connectivity is checked at most every
  /// few seconds, and a check made as the connection comes back may still find it offline.
  void _scheduleRetry() {
    _retryTimer?.cancel();
    // Coming back to the app tries again anyway.
    if (WidgetsBinding.instance.lifecycleState case .hidden || .paused || .detached) return;
    _retryTimer = Timer(ref.read(drillSendRetryDelayProvider), _retrySendingPendingSolutions);
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
    if (_isSendingPendingSolutions) {
      _shouldRetrySendingPendingSolutions = true;
      return;
    }

    final userId = drill.puzzleContext.userId;
    final angle = drill.drill.config.angle;
    _isSendingPendingSolutions = true;
    var isStillPending = true;
    try {
      final batchStorage = await ref.read(puzzleBatchStorageProvider.future);
      final batch = await batchStorage.fetch(userId: userId, angle: angle);
      if (batch == null || batch.solved.isEmpty || !ref.mounted) {
        isStillPending = false;
        return;
      }
      final service = await _puzzleService(angle);
      final synced = await service.syncSolutions(userId: userId, angle: angle);
      if (!ref.mounted) return;
      if (state?.puzzleContext != drill.puzzleContext) {
        // Another Drill started meanwhile: the ended one is only in the Drill History now.
        if (userId != null) {
          ref
              .read(drillHistoryProvider.notifier)
              .recordRatingDiffs(userId, synced.rounds, except: state?.drill.startedAt);
        }
      } else {
        _onSync(rounds: synced.rounds, glicko: synced.glicko);
        final remaining = await batchStorage.fetch(userId: userId, angle: angle);
        isStillPending = remaining != null && remaining.solved.isNotEmpty;
      }
    } catch (e, st) {
      // The solutions stay pending, as when they can't be sent.
      _logger.warning('Failed to send the pending solutions', e, st);
    } finally {
      _isSendingPendingSolutions = false;
      if (ref.mounted) {
        if (_shouldRetrySendingPendingSolutions) {
          _shouldRetrySendingPendingSolutions = false;
          _retrySendingPendingSolutions();
        } else if (isStillPending && state?.puzzleContext == drill.puzzleContext) {
          _scheduleRetry();
        }
      }
    }
  }
}

extension on PuzzleGlicko {
  /// The rating as Lichess shows it, and computes the rating diff of each solution from: without
  /// its decimals, not rounded.
  int get shownRating => rating.toInt();
}

/// Times the puzzle being solved: from when the player can move to its result, only while the app
/// is shown.
class _SolvingClock(final ValueChanged<DrillSolvingTime> _onChange) {
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

  DrillSolvingTime _time = const DrillSolvingTime();

  /// Whether a puzzle is being timed, even while the app is hidden.
  bool get isRunning => _isRunning;

  /// Starts timing a new puzzle.
  void start() {
    _isRunning = true;
    _time = const DrillSolvingTime();
    _update();
  }

  /// Stops timing the puzzle and returns the time spent on it.
  Duration stop() {
    _isRunning = false;
    _update();
    return _time.elapsed;
  }

  void dispose() => _appLifecycleListener.dispose();

  void _setAppHidden(bool isHidden) {
    _isAppHidden = isHidden;
    _update();
  }

  void _update() {
    final shouldRun = _isRunning && !_isAppHidden;
    if (_time.isRunning && !shouldRun) {
      _time = DrillSolvingTime(elapsed: _time.at(clock.now()));
    } else if (!_time.isRunning && shouldRun) {
      _time = _time.copyWith(runningSince: clock.now());
    }
    _onChange(_time);
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
sealed class const DrillState._() with _$DrillState {
  const factory({
    required Drill drill,

    /// The context of the [PuzzleController] solving the Drill's puzzles.
    ///
    /// It is the context of the first puzzle played: the same controller loads the following ones.
    required PuzzleContext puzzleContext,

    /// The number of the puzzle being solved, from 1.
    required int puzzleNumber,

    /// The time spent on the puzzle being solved so far, or on the last one once it is solved.
    @Default(DrillSolvingTime()) DrillSolvingTime solvingTime,
    @Default(false) bool isOver,
  }) = _DrillState;

  /// Whether the Drill counts on an account: played signed out, it is unrated, without a rating,
  /// and none of its solutions are sent.
  bool get hasAccount => puzzleContext.userId != null;
}

/// The time spent on a puzzle of a Drill, timed from when the player can move to its result, only
/// while the app is shown.
@freezed
sealed class const DrillSolvingTime._() with _$DrillSolvingTime {
  const factory({
    /// The time spent up to [runningSince].
    @Default(Duration.zero) Duration elapsed,

    /// Since when the time has been running, or `null` while it doesn't.
    DateTime? runningSince,
  }) = _DrillSolvingTime;

  bool get isRunning => runningSince != null;

  /// The time spent at [now].
  Duration at(DateTime now) {
    final since = runningSince;
    return since == null ? elapsed : elapsed + now.difference(since);
  }
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

  /// The share of puzzles the player was expected to solve, from 0 to 1, or `null` if their rating
  /// when the Drill started is unknown or no puzzle was solved.
  ///
  /// Each puzzle's chance is the expected score of the rating formula between the player's rating
  /// and the puzzle's (Glicko's, leaving out the rating deviation), so that it is about 50 % for a
  /// puzzle at the player's rating whatever the difficulty.
  double? get expectedSuccessRate {
    final rating = ratingBefore;
    if (rating == null || results.isEmpty) return null;
    return results.map((r) => 1 / (1 + math.pow(10, (r.puzzleRating - rating) / 400))).average;
  }

  /// Whether no result counts for the player's rating: the Drill was played with rated puzzles off,
  /// or, in a Drill played before a hint failed the puzzle, with a hint for each puzzle.
  bool get isCasual => results.isNotEmpty && results.every((r) => !r.rated);

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

  /// The Drill with the rating changes of the solutions sent in [rounds] given to its rated
  /// results still without one.
  Drill withRatingDiffs(IList<PuzzleRound>? rounds) {
    final ratingDiffs = {
      for (final round in rounds ?? const <PuzzleRound>[]) round.id: round.ratingDiff,
    };
    if (ratingDiffs.isEmpty) return this;
    return copyWith(
      results: results
          .map(
            (r) => r.isRatingDiffPending && ratingDiffs.containsKey(r.id)
                ? r.copyWith(ratingDiff: ratingDiffs[r.id])
                : r,
          )
          .toIList(),
    );
  }

  /// The sum of the rating changes known.
  int get ratingDiffsTotal => results.fold(0, (total, r) => total + (r.ratingDiff ?? 0));

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
