import 'package:clock/clock.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lichess_mobile/src/model/auth/auth_controller.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/drill/drill_controller.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_angle.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_controller.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_difficulty.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_preferences.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_theme.dart';
import 'package:lichess_mobile/src/model/user/user.dart';
import 'package:lichess_mobile/src/network/http.dart';
import 'package:lichess_mobile/src/service/puzzle_service.dart';

import '../../network/fake_http_client_factory.dart';
import '../../test_container.dart';
import '../auth/fake_auth_storage.dart';
import 'fake_drill_server.dart';

void main() {
  // A Drill pauses the puzzle being solved while the app is in the background.
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeDrillServer server;

  setUp(() => server = FakeDrillServer());

  Future<ProviderContainer> makeDrillContainer({AuthUser authUser = fakeAuthUser}) => makeContainer(
    authUser: authUser,
    overrides: {
      httpClientFactoryProvider: httpClientFactoryProvider.overrideWith(
        (ref) => FakeHttpClientFactory(() => server.client),
      ),
    },
  );

  test('starting a Drill loads its first puzzle', () async {
    final container = await makeDrillContainer();

    final started = await container.read(drillControllerProvider.notifier).start(_drill);

    expect(started, isTrue);
    final drill = container.read(drillControllerProvider)!;
    expect(drill.puzzleNumber, 1);
    expect(drill.isOver, isFalse);
    expect(drill.puzzleContext.puzzle.puzzle.id.value, startsWith('drill'));
  });

  test('a Drill is played at its difficulty, whatever the puzzles queued before', () async {
    final container = await makeDrillContainer();
    await container
        .read(puzzlePreferencesProvider.notifier)
        .setDifficulty(PuzzleDifficulty.hardest);
    // puzzles queued at another difficulty
    await container.read(puzzleServiceProvider.future).then((s) => s.nextPuzzle(userId: _userId));
    final queuedPuzzles = server.nbServed;

    await container.read(drillControllerProvider.notifier).start(_drill);

    expect(server.difficulties.last, 'normal');
    final drill = container.read(drillControllerProvider)!;
    expect(drill.puzzleContext.puzzle.puzzle.id.value, 'drill$queuedPuzzles');
  });

  test('a Drill ends after its last puzzle, with its summary', () async {
    final container = await makeDrillContainer();
    final drillCtrl = container.read(drillControllerProvider.notifier);
    await drillCtrl.start(_drill);

    for (final (index, win) in [true, false, true, true, false].indexed) {
      await _solveCurrentPuzzle(container, win: win);
      final drill = container.read(drillControllerProvider)!;
      expect(drill.puzzleNumber, index + 1, reason: 'still on the solved puzzle');
      expect(drill.isOver, isFalse, reason: 'the player has not moved on yet');
      drillCtrl.continueDrill();
    }

    final drill = container.read(drillControllerProvider)!;
    expect(drill.isOver, isTrue);
    expect(drill.drill.successes, 3);
    expect(drill.drill.failures, 2);
    expect(drill.drill.successRate, 0.6);
    expect(drill.drill.performance, 1600);
    expect(drill.drill.isPerformanceReliable, isFalse, reason: 'fewer than 6 puzzles');
    expect(server.solutions.map((s) => s.win), [true, false, true, true, false]);
  });

  test('a Drill is played with its number of puzzles, theme and difficulty', () async {
    final container = await makeDrillContainer();
    final drillCtrl = container.read(drillControllerProvider.notifier);
    await drillCtrl.start(
      const DrillConfig(
        nbPuzzles: 12,
        angle: PuzzleTheme(PuzzleThemeKey.fork),
        difficulty: PuzzleDifficulty.hardest,
      ),
    );

    for (var i = 0; i < 12; i++) {
      expect(container.read(drillControllerProvider)!.isOver, isFalse);
      await _solveCurrentPuzzle(container, win: true);
      drillCtrl.continueDrill();
    }

    expect(container.read(drillControllerProvider)!.isOver, isTrue);
    expect(server.solutions, hasLength(12));
    expect(server.angles.toSet(), {'fork'});
    expect(server.difficulties.toSet(), {'hardest'});
  });

  test('a Drill can be played on an opening', () async {
    final container = await makeDrillContainer();

    await container
        .read(drillControllerProvider.notifier)
        .start(const DrillConfig(nbPuzzles: 5, angle: PuzzleOpening('Sicilian_Defense')));

    expect(server.angles.toSet(), {'Sicilian_Defense'});
  });

  test('the configuration of the last Drill started is remembered', () async {
    final container = await makeDrillContainer();
    expect(container.read(lastDrillConfigProvider), const DrillConfig(nbPuzzles: 10));
    const config = DrillConfig(
      nbPuzzles: 37,
      angle: PuzzleOpening('Sicilian_Defense'),
      difficulty: PuzzleDifficulty.easier,
    );

    await container.read(drillControllerProvider.notifier).start(config);

    expect(container.read(lastDrillConfigProvider), config);
    container.dispose();
    final restarted = await makeDrillContainer();
    expect(restarted.read(lastDrillConfigProvider), config);
  });

  test('with auto-next, a solved puzzle moves on by itself, but a failed one waits', () async {
    final container = await makeDrillContainer();
    await container.read(puzzlePreferencesProvider.notifier).setAutoNext(true);
    final drillCtrl = container.read(drillControllerProvider.notifier);
    await drillCtrl.start(_drill);

    await _solveCurrentPuzzle(container, win: true);
    expect(container.read(drillControllerProvider)!.puzzleNumber, 2);

    await _solveCurrentPuzzle(container, win: false);
    expect(container.read(drillControllerProvider)!.puzzleNumber, 2);
    drillCtrl.continueDrill();
    expect(container.read(drillControllerProvider)!.puzzleNumber, 3);

    for (var i = 0; i < 3; i++) {
      await _solveCurrentPuzzle(container, win: true);
    }
    final drill = container.read(drillControllerProvider)!;
    expect(drill.isOver, isTrue, reason: 'solving the last puzzle ends the Drill');
    expect(drill.drill.successes, 4);
    expect(drill.drill.failures, 1);
  });

  test('a puzzle is unrated when a hint was used or rated puzzles are off', () async {
    final container = await makeDrillContainer();
    final drillCtrl = container.read(drillControllerProvider.notifier);
    await drillCtrl.start(_drill);

    await _solveCurrentPuzzle(container, win: true, hint: true);
    drillCtrl.continueDrill();
    await _solveCurrentPuzzle(container, win: true);
    drillCtrl.continueDrill();
    await container.read(puzzlePreferencesProvider.notifier).setRated(false);
    await _solveCurrentPuzzle(container, win: true);

    expect(server.solutions.map((s) => s.rated), [false, true, false]);
  });

  test("the Drill Summary has each puzzle's result and the rating before and after", () async {
    server.puzzleRatingOf = (index) => 1400 + index * 100;
    final container = await makeDrillContainer();
    final drillCtrl = container.read(drillControllerProvider.notifier);
    await drillCtrl.start(const DrillConfig(nbPuzzles: 4));

    await _solveCurrentPuzzle(container, win: true);
    drillCtrl.continueDrill();
    await _solveCurrentPuzzle(container, win: false);
    drillCtrl.continueDrill();
    await _solveCurrentPuzzle(container, win: true, hint: true);
    drillCtrl.continueDrill();
    await _solveCurrentPuzzle(container, win: true);
    drillCtrl.continueDrill();

    final drill = container.read(drillControllerProvider)!;
    expect(drill.isOver, isTrue);
    expect(drill.drill.results.map((r) => r.puzzleRating), [1400, 1500, 1600, 1700]);
    expect(drill.drill.results.first.themes, ISet(const ['endgame', 'short', 'fork']));
    expect(drill.drill.results.map((r) => r.win), [true, false, true, true]);
    expect(drill.drill.results.map((r) => r.rated), [true, true, false, true]);
    expect(drill.drill.results.map((r) => r.ratingDiff), [10, -10, null, 10]);
    expect(drill.drill.ratingBefore, 1500);
    expect(drill.drill.ratingAfter, 1510);
    expect(drill.drill.ratingChange, 10);
  });

  test('the Drill Summary has the Drill Performance and the weakest themes', () async {
    server.puzzleRatingOf = (index) => 1500 + index * 100;
    server.puzzleThemesOf = (index) => switch (index) {
      1 => const ['fork', 'short', 'middlegame', 'crushing'],
      4 => const ['pin', 'fork', 'long', 'advantage'],
      _ => const ['skewer', 'mateIn2', 'mate'],
    };
    final container = await makeDrillContainer();
    final drillCtrl = container.read(drillControllerProvider.notifier);
    await drillCtrl.start(const DrillConfig(nbPuzzles: 6));

    for (final win in [true, false, true, true, false, true]) {
      await _solveCurrentPuzzle(container, win: win);
      drillCtrl.continueDrill();
    }

    final drill = container.read(drillControllerProvider)!;
    expect(drill.isOver, isTrue);
    // 1750 average puzzle rating, 4 successes out of 6
    expect(drill.drill.performance, 1917);
    expect(drill.drill.isPerformanceReliable, isTrue);
    // length and advantage themes are left out
    expect(drill.drill.weakestThemes, [
      (theme: 'fork', failures: 2),
      (theme: 'middlegame', failures: 1),
      (theme: 'pin', failures: 1),
    ]);
  });

  test('a puzzle is timed only while it is being solved and the app is shown', () async {
    var now = DateTime(2026, 10, 21);
    await withClock(Clock(() => now), () async {
      final container = await makeDrillContainer();
      final drillCtrl = container.read(drillControllerProvider.notifier);
      await drillCtrl.start(const DrillConfig(nbPuzzles: 2));
      final binding = TestWidgetsFlutterBinding.instance;
      void setAppLifecycleStates(List<AppLifecycleState> states) =>
          states.forEach(binding.handleAppLifecycleStateChanged);
      if (binding.lifecycleState != .resumed) setAppLifecycleStates(const [.resumed]);

      await _solveCurrentPuzzle(
        container,
        win: true,
        whilePlaying: () => now = now.add(const Duration(seconds: 20)),
      );
      // between puzzles
      now = now.add(const Duration(minutes: 1));
      drillCtrl.continueDrill();
      await _solveCurrentPuzzle(
        container,
        win: false,
        whilePlaying: () {
          now = now.add(const Duration(seconds: 10));
          setAppLifecycleStates(const [.inactive, .hidden, .paused]);
          now = now.add(const Duration(minutes: 5));
          setAppLifecycleStates(const [.hidden, .inactive, .resumed]);
          now = now.add(const Duration(seconds: 5));
        },
      );
      now = now.add(const Duration(minutes: 1));
      drillCtrl.continueDrill();

      final drill = container.read(drillControllerProvider)!;
      expect(drill.isOver, isTrue);
      expect(drill.drill.results.map((r) => r.solvingTime), const [
        Duration(seconds: 20),
        Duration(seconds: 15),
      ]);
      expect(drill.drill.totalSolvingTime, const Duration(seconds: 35));
      expect(drill.drill.averageSolvingTime, const Duration(milliseconds: 17500));
    });
  });

  test('pending solutions are sent as soon as the Drill ends', () async {
    final container = await makeDrillContainer();
    final drillCtrl = container.read(drillControllerProvider.notifier);
    await drillCtrl.start(const DrillConfig(nbPuzzles: 2));

    await _solveCurrentPuzzle(container, win: true);
    drillCtrl.continueDrill();
    server.isOffline = true;
    await _solveCurrentPuzzle(container, win: true);

    var drill = container.read(drillControllerProvider)!;
    expect(server.solutions, hasLength(1));
    expect(drill.drill.results.map((r) => r.ratingDiff), [10, null]);
    expect(drill.drill.ratingAfter, isNull, reason: 'pending');
    expect(drill.drill.ratingChange, isNull, reason: 'pending');

    server.isOffline = false;
    drillCtrl.continueDrill();
    await _waitFor(() => server.solutions.length == 2);
    await _waitFor(() => !container.read(drillControllerProvider)!.drill.hasPendingRatingDiff);

    drill = container.read(drillControllerProvider)!;
    expect(drill.isOver, isTrue);
    expect(drill.drill.results.map((r) => r.ratingDiff), [10, 10]);
    expect(drill.drill.ratingAfter, 1520);
    expect(drill.drill.ratingChange, 20);
  });

  test('ending a Drill early makes it a Partial Drill of the puzzles solved', () async {
    final container = await makeDrillContainer();
    final drillCtrl = container.read(drillControllerProvider.notifier);
    await drillCtrl.start(_drill);

    await _solveCurrentPuzzle(container, win: true);
    drillCtrl.continueDrill();
    await _solveCurrentPuzzle(container, win: false);
    drillCtrl.continueDrill();
    // the third puzzle is left without a result
    await _waitFor(() => _puzzleState(container).mode == .play);
    drillCtrl.end();

    final drill = container.read(drillControllerProvider)!;
    expect(drill.isOver, isTrue);
    expect(drill.drill.isPartial, isTrue);
    expect(drill.drill.results.map((r) => r.win), [true, false]);
    expect(container.read(unfinishedDrillProvider), isNull, reason: 'not offered for resuming');
  });

  test('a Drill solved to its last puzzle is not partial', () async {
    final container = await makeDrillContainer();
    final drillCtrl = container.read(drillControllerProvider.notifier);
    await drillCtrl.start(const DrillConfig(nbPuzzles: 1));

    await _solveCurrentPuzzle(container, win: true);
    drillCtrl.continueDrill();

    final drill = container.read(drillControllerProvider)!;
    expect(drill.isOver, isTrue);
    expect(drill.drill.isPartial, isFalse);
  });

  test('a Drill ended before any puzzle is solved is discarded', () async {
    final container = await makeDrillContainer();
    final drillCtrl = container.read(drillControllerProvider.notifier);
    await drillCtrl.start(_drill);
    expect(container.read(unfinishedDrillProvider), isNotNull);

    drillCtrl.end();

    expect(container.read(drillControllerProvider), isNull);
    expect(container.read(unfinishedDrillProvider), isNull);
  });

  test('an unfinished Drill is resumed after the app restarts', () async {
    var now = DateTime(2026, 10, 21, 9);
    await withClock(Clock(() => now), () async {
      final container = await makeDrillContainer();
      final drillCtrl = container.read(drillControllerProvider.notifier);
      await drillCtrl.start(_drill);
      await _solveCurrentPuzzle(container, win: true);
      drillCtrl.continueDrill();
      await _solveCurrentPuzzle(container, win: false);
      container.dispose();

      now = now.add(const Duration(hours: 5));
      final restarted = await makeDrillContainer();
      final unfinished = restarted.read(unfinishedDrillProvider)!;
      expect(unfinished.results.map((r) => r.win), [true, false]);
      expect(unfinished.startedAt, DateTime(2026, 10, 21, 9));

      final restartedCtrl = restarted.read(drillControllerProvider.notifier);
      expect(await restartedCtrl.resume(), isTrue);
      expect(restarted.read(drillControllerProvider)!.puzzleNumber, 3);
      for (var i = 0; i < 3; i++) {
        await _solveCurrentPuzzle(restarted, win: true);
        restartedCtrl.continueDrill();
      }

      final drill = restarted.read(drillControllerProvider)!;
      expect(drill.isOver, isTrue);
      expect(drill.drill.isPartial, isFalse);
      expect(drill.drill.results.map((r) => r.win), [true, false, true, true, true]);
      expect(drill.drill.ratingBefore, FakeDrillServer.initialRating);
      expect(restarted.read(unfinishedDrillProvider), isNull);
    });
  });

  test('an unfinished Drill can be resumed any time later', () async {
    var now = DateTime(2026, 10, 21, 9);
    await withClock(Clock(() => now), () async {
      final container = await makeDrillContainer();
      await container.read(drillControllerProvider.notifier).start(_drill);
      await _solveCurrentPuzzle(container, win: true);
      container.dispose();

      now = now.add(const Duration(days: 30));
      final restarted = await makeDrillContainer();

      expect(restarted.read(unfinishedDrillProvider), isNotNull);
      expect(await restarted.read(drillControllerProvider.notifier).resume(), isTrue);
      expect(restarted.read(drillControllerProvider)!.puzzleNumber, 2);
    });
  });

  test('each account has its own unfinished Drill and last configuration', () async {
    final container = await makeDrillContainer();
    await container.read(drillControllerProvider.notifier).start(_drill);
    await _solveCurrentPuzzle(container, win: true);
    container.dispose();

    final other = await makeDrillContainer(authUser: _otherAuthUser);
    expect(other.read(unfinishedDrillProvider), isNull);
    expect(other.read(lastDrillConfigProvider), const DrillConfig(nbPuzzles: 10));
    final otherCtrl = other.read(drillControllerProvider.notifier);
    await otherCtrl.start(const DrillConfig(nbPuzzles: 12));
    await _solveCurrentPuzzle(other, win: false);
    otherCtrl.continueDrill();
    await _solveCurrentPuzzle(other, win: false);
    other.dispose();

    final back = await makeDrillContainer();
    expect(back.read(unfinishedDrillProvider)!.results.map((r) => r.win), [true]);
    expect(back.read(lastDrillConfigProvider), _drill);
    expect(await back.read(drillControllerProvider.notifier).resume(), isTrue);
    expect(back.read(drillControllerProvider)!.drill.config, _drill);
  });

  test('signing out leaves the Drill being played to its account', () async {
    final container = await makeDrillContainer();
    final drillCtrl = container.read(drillControllerProvider.notifier);
    await drillCtrl.start(_drill);
    await _solveCurrentPuzzle(container, win: true);

    await container.read(authControllerProvider.notifier).signOut();

    expect(container.read(drillControllerProvider), isNull);
    expect(container.read(unfinishedDrillProvider), isNull);
    expect(await drillCtrl.resume(), isFalse);
    container.dispose();
    final restarted = await makeDrillContainer();
    expect(restarted.read(unfinishedDrillProvider)!.results, hasLength(1));
  });

  test('starting a new Drill ends the unfinished one', () async {
    final container = await makeDrillContainer();
    final drillCtrl = container.read(drillControllerProvider.notifier);
    await drillCtrl.start(_drill);
    await _solveCurrentPuzzle(container, win: true);

    await drillCtrl.start(const DrillConfig(nbPuzzles: 3));

    expect(container.read(unfinishedDrillProvider)!.config.nbPuzzles, 3);
    expect(container.read(drillControllerProvider)!.puzzleNumber, 1);
  });
}

PuzzleState _puzzleState(ProviderContainer container) => container.read(
  puzzleControllerProvider(container.read(drillControllerProvider)!.puzzleContext),
);

/// Solves the puzzle the Drill is on, waiting for its result to be sent to the server.
///
/// It is won by playing the solution, or lost by viewing the solution. [whilePlaying] is called
/// once the player can move, before the puzzle is solved.
Future<void> _solveCurrentPuzzle(
  ProviderContainer container, {
  required bool win,
  bool hint = false,
  void Function()? whilePlaying,
}) async {
  final ctrlProvider = puzzleControllerProvider(
    container.read(drillControllerProvider)!.puzzleContext,
  );
  final puzzleCtrl = container.read(ctrlProvider.notifier);
  final puzzleId = container.read(ctrlProvider).puzzle.puzzle.id;

  // the opponent's move is played after 1 second
  await _waitFor(() => container.read(ctrlProvider).mode == .play);
  whilePlaying?.call();
  if (hint) puzzleCtrl.toggleHint();
  if (win) {
    for (final move in FakeDrillServer.playerMoves) {
      await puzzleCtrl.onUserMove(move);
    }
  } else {
    puzzleCtrl.viewSolution();
  }
  // the solution is sent and the next puzzle prepared, or already loaded with auto-next
  await _waitFor(() {
    final state = container.read(ctrlProvider);
    return state.nextContext != null || state.puzzle.puzzle.id != puzzleId;
  });
}

Future<void> _waitFor(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  expect(condition(), isTrue, reason: 'timed out');
}

const _drill = DrillConfig(nbPuzzles: 5);

final _userId = fakeAuthUser.user.id;

const _otherAuthUser = AuthUser(
  token: 'otherToken',
  user: LightUser(id: UserId('otheruser'), name: 'otherUser'),
);
