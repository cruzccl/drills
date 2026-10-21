import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lichess_mobile/src/model/auth/auth_controller.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_angle.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_controller.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_difficulty.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_preferences.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_theme.dart';
import 'package:lichess_mobile/src/model/settings/preferences_storage.dart';
import 'package:lichess_mobile/src/service/puzzle_service.dart';

part 'drill_controller.freezed.dart';
part 'drill_controller.g.dart';

/// The Drill being played, or `null` when there is none.
final drillControllerProvider = NotifierProvider<DrillController, DrillState?>(
  DrillController.new,
  name: 'DrillControllerProvider',
);

/// Owns the lifecycle of a Drill: starts it, records the outcome of each puzzle and ends it.
///
/// Puzzles are solved by the [PuzzleController] of [DrillState.puzzleContext], which applies the
/// official result rules and sends the solutions through the [PuzzleService]. The Drill counts
/// and records on top of it.
class DrillController() extends Notifier<DrillState?> {
  ProviderSubscription<PuzzleState>? _puzzleSubscription;

  @override
  DrillState? build() => null;

  /// Starts a new Drill with [config], replacing the current one if any.
  ///
  /// Returns `false` if no puzzle could be loaded.
  Future<bool> start(DrillConfig config) async {
    final userId = ref.read(authControllerProvider)?.user.id;
    final puzzlePrefs = ref.read(puzzlePreferencesProvider);
    final service = await ref.read(puzzleServiceFactoryProvider)(
      queueLength: offlineQueueLengthForAngle(config.angle, puzzlePrefs.nbOfflinePuzzles),
    );
    // The puzzle service and controller fetch puzzles at the difficulty of the preferences, which
    // Drills don't expose otherwise. The puzzles queued at another difficulty are dropped, as when
    // the difficulty is changed in the official app.
    if (puzzlePrefs.difficulty != config.difficulty) {
      await ref.read(puzzlePreferencesProvider.notifier).setDifficulty(config.difficulty);
      await service.deleteBatch(userId: userId, angle: config.angle);
    }
    final puzzleContext = await service.nextPuzzle(userId: userId, angle: config.angle);
    if (puzzleContext == null) return false;

    await ref.read(lastDrillConfigProvider.notifier).save(config);
    _puzzleSubscription?.close();
    state = DrillState(config: config, puzzleContext: puzzleContext, puzzleNumber: 1);
    _puzzleSubscription = ref.listen(puzzleControllerProvider(puzzleContext), _onPuzzleStateChange);
    return true;
  }

  /// Moves on from the solved puzzle: to the next one, or to the end of the Drill after the last.
  void continueDrill() {
    final drill = state;
    if (drill == null || drill.isOver) return;

    if (drill.isLimitReached) {
      _end();
      return;
    }
    final puzzleCtrlProvider = puzzleControllerProvider(drill.puzzleContext);
    final nextContext = ref.read(puzzleCtrlProvider).nextContext;
    if (nextContext != null) {
      ref.read(puzzleCtrlProvider.notifier).onLoadPuzzle(nextContext);
    }
  }

  void _onPuzzleStateChange(PuzzleState? previous, PuzzleState next) {
    final drill = state;
    if (drill == null || drill.isOver) return;

    final puzzleId = next.puzzle.puzzle.id;
    final result = next.result;
    if (previous != null && previous.puzzle.puzzle.id != puzzleId) {
      // The next puzzle was loaded, by [continueDrill] or by the puzzle controller itself when
      // auto-next is on.
      if (drill.isLimitReached) {
        _end();
      } else {
        state = drill.copyWith(puzzleNumber: drill.puzzleNumber + 1);
      }
    } else if (result != null && drill.results.lastOrNull?.id != puzzleId) {
      state = drill.copyWith(
        results: drill.results.add(DrillPuzzleResult(id: puzzleId, win: result == .win)),
      );
    }
  }

  void _end() {
    _puzzleSubscription?.close();
    _puzzleSubscription = null;
    state = state?.copyWith(isOver: true);
  }
}

/// The configuration of the last Drill started, preselected to set up the next one.
final lastDrillConfigProvider = NotifierProvider<LastDrillConfig, DrillConfig>(
  LastDrillConfig.new,
  name: 'LastDrillConfigProvider',
);

class LastDrillConfig() extends Notifier<DrillConfig> with PreferencesStorage<DrillConfig> {
  @override
  @protected
  final prefCategory = PrefCategory.drill;

  @override
  DrillConfig get defaults => const DrillConfig(nbPuzzles: 10);

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

/// The largest number of puzzles a Drill can have.
///
/// It is the most puzzles a batch request returns ([kServerPuzzleBatchCap]), so that a Drill's
/// puzzles can all be downloaded at once.
const kMaxDrillPuzzles = kServerPuzzleBatchCap;

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

@freezed
sealed class const DrillState._() with _$DrillState {
  const factory({
    required DrillConfig config,

    /// The context of the [PuzzleController] solving the Drill's puzzles.
    ///
    /// It is the context of the first puzzle: the same controller loads the following ones.
    required PuzzleContext puzzleContext,

    /// The number of the puzzle being solved, from 1.
    required int puzzleNumber,

    /// The outcome of each puzzle solved, in order.
    @Default(IListConst<DrillPuzzleResult>([])) IList<DrillPuzzleResult> results,
    @Default(false) bool isOver,
  }) = _DrillState;

  /// Whether every puzzle of the Drill has been solved.
  bool get isLimitReached => results.length >= config.nbPuzzles;

  int get successes => results.where((r) => r.win).length;

  int get failures => results.length - successes;

  /// The share of puzzles solved, from 0 to 1, or 0 if no puzzle was solved.
  double get successRate => results.isEmpty ? 0 : successes / results.length;
}

/// The outcome of a puzzle of a Drill.
@freezed
sealed class DrillPuzzleResult with _$DrillPuzzleResult {
  const factory({required PuzzleId id, required bool win}) = _DrillPuzzleResult;
}
