import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lichess_mobile/src/db/drill_database.dart';
import 'package:lichess_mobile/src/model/auth/auth_controller.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/drill/drill_controller.dart';
import 'package:lichess_mobile/src/model/drill/drill_history.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_angle.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_controller.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_difficulty.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_preferences.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_solve_limit.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_theme.dart';
import 'package:lichess_mobile/src/model/user/user.dart';
import 'package:lichess_mobile/src/network/connectivity.dart';
import 'package:lichess_mobile/src/network/http.dart';
import 'package:lichess_mobile/src/service/puzzle_service.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../network/fake_http_client_factory.dart';
import '../../test_container.dart';
import '../../utils/fake_connectivity.dart';
import '../auth/fake_auth_storage.dart';
import 'fake_drill_server.dart';

void main() {
  // A Drill pauses the puzzle being solved while the app is in the background.
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeDrillServer server;

  /// The database of Drills, kept on the device across app restarts.
  late Database drillDatabase;

  setUp(() async {
    server = FakeDrillServer();
    drillDatabase = await openDrillDatabase(
      databaseFactoryFfi,
      inMemoryDatabasePath,
      singleInstance: false,
    );
  });

  tearDown(() => drillDatabase.close());

  Future<ProviderContainer> makeDrillContainer({AuthUser authUser = fakeAuthUser}) => makeContainer(
    authUser: authUser,
    overrides: {
      httpClientFactoryProvider: httpClientFactoryProvider.overrideWith(
        (ref) => FakeHttpClientFactory(() => server.client),
      ),
      drillSendRetryDelayProvider: drillSendRetryDelayProvider.overrideWithValue(
        const Duration(seconds: 1),
      ),
      drillDatabaseProvider: drillDatabaseProvider.overrideWith((ref) => drillDatabase),
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

  test('a hint fails the puzzle on Lichess, rated, even if it is then solved', () async {
    final container = await makeDrillContainer();
    await container.read(drillControllerProvider.notifier).start(_drill);

    await _solveCurrentPuzzle(container, win: true, hint: true);

    expect(server.solutions.map((s) => (win: s.win, rated: s.rated)), [(win: false, rated: true)]);
    final result = container.read(drillControllerProvider)!.drill.results.single;
    expect(result.win, isFalse);
    expect(result.rated, isTrue);
    expect(result.ratingDiff, -10);
    expect(_puzzleState(container).result, PuzzleResult.lose);
  });

  test('later hints only show the hint, and a hint stays shown', () async {
    final container = await makeDrillContainer();
    await container.read(drillControllerProvider.notifier).start(_drill);

    await _solveCurrentPuzzle(
      container,
      win: true,
      waitForNext: false,
      whilePlaying: () {
        _puzzleCtrl(container).showHintAsFailure();
        _puzzleCtrl(container).showHintAsFailure();
        expect(_puzzleState(container).hintSquare, Square.g4);
      },
    );
    await _waitFor(() => _puzzleState(container).nextContext != null);

    expect(server.solutions, hasLength(1));
  });

  test('a hint after a wrong move only shows the hint', () async {
    final container = await makeDrillContainer();
    await container.read(drillControllerProvider.notifier).start(_drill);
    final puzzleCtrl = _puzzleCtrl(container);
    await _waitFor(() => _puzzleState(container).mode == .play);

    await puzzleCtrl.onUserMove(Move.parse('g4g3')!);
    await _waitFor(() => _puzzleState(container).nextContext != null);
    puzzleCtrl.showHintAsFailure();

    expect(_puzzleState(container).hintSquare, Square.g4);
    expect(server.solutions.map((s) => s.win), [false]);
    expect(container.read(drillControllerProvider)!.drill.results.single.win, isFalse);
  });

  test('no hint is given while the opponent is to move', () async {
    final container = await makeDrillContainer();
    await container.read(drillControllerProvider.notifier).start(_drill);
    final puzzleCtrl = _puzzleCtrl(container);
    await _waitFor(() => _puzzleState(container).mode == .play);

    // the opponent replies 500 ms after the player's right move
    final playing = puzzleCtrl.onUserMove(FakeDrillServer.playerMoves.first);
    puzzleCtrl.showHintAsFailure();
    await playing;

    expect(_puzzleState(container).hintSquare, isNull);
    expect(_puzzleState(container).result, isNull);
    expect(container.read(drillControllerProvider)!.drill.results, isEmpty);
  });

  test('a puzzle is unrated when rated puzzles are off', () async {
    final container = await makeDrillContainer();
    final drillCtrl = container.read(drillControllerProvider.notifier);
    await drillCtrl.start(_drill);

    await _solveCurrentPuzzle(container, win: true);
    drillCtrl.continueDrill();
    await container.read(puzzlePreferencesProvider.notifier).setRated(false);
    await _solveCurrentPuzzle(container, win: true, hint: true);

    expect(server.solutions.map((s) => s.rated), [true, false]);
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
    expect(drill.drill.results.map((r) => r.win), [true, false, false, true]);
    expect(drill.drill.results.map((r) => r.rated), [true, true, true, true]);
    expect(drill.drill.results.map((r) => r.ratingDiff), [10, -10, -10, 10]);
    expect(drill.drill.ratingBefore, 1500);
    expect(drill.drill.ratingAfter, 1500);
    expect(drill.drill.ratingChange, 0);
  });

  test('the rating before and after a Drill leave out its decimals, as on Lichess', () async {
    server.ratingDecimals = 0.6;
    final container = await makeDrillContainer();
    await container.read(drillControllerProvider.notifier).start(const DrillConfig(nbPuzzles: 1));

    // 1500.6 then 1490.4: Lichess shows 1500 then 1490, and a rating diff of -10
    await _solveCurrentPuzzle(
      container,
      win: false,
      whilePlaying: () => server.ratingDecimals = 0.4,
    );

    final drill = container.read(drillControllerProvider)!.drill;
    expect(drill.ratingBefore, 1500);
    expect(drill.ratingAfter, 1490);
    expect(drill.ratingChange, -10);
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
      if (TestWidgetsFlutterBinding.instance.lifecycleState != .resumed) {
        _setAppLifecycleStates(const [.resumed]);
      }

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
          _setAppLifecycleStates(const [.inactive, .hidden, .paused]);
          now = now.add(const Duration(minutes: 5));
          _setAppLifecycleStates(const [.hidden, .inactive, .resumed]);
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

  test('the time spent on the puzzle being solved is in the state, to be shown', () async {
    var now = DateTime(2026, 10, 21);
    await withClock(Clock(() => now), () async {
      final container = await makeDrillContainer();
      final drillCtrl = container.read(drillControllerProvider.notifier);
      await drillCtrl.start(const DrillConfig(nbPuzzles: 2));
      if (TestWidgetsFlutterBinding.instance.lifecycleState != .resumed) {
        _setAppLifecycleStates(const [.resumed]);
      }
      DrillSolvingTime solvingTime() => container.read(drillControllerProvider)!.solvingTime;

      await _solveCurrentPuzzle(
        container,
        win: true,
        whilePlaying: () {
          expect(solvingTime().isRunning, isTrue);
          now = now.add(const Duration(seconds: 10));
          expect(solvingTime().at(now), const Duration(seconds: 10));
          _setAppLifecycleStates(const [.inactive, .hidden, .paused]);
          expect(solvingTime(), const DrillSolvingTime(elapsed: Duration(seconds: 10)));
          now = now.add(const Duration(minutes: 5));
          _setAppLifecycleStates(const [.hidden, .inactive, .resumed]);
          expect(solvingTime().isRunning, isTrue);
          now = now.add(const Duration(seconds: 5));
        },
      );
      // stopped at the result, until the next puzzle
      expect(solvingTime(), const DrillSolvingTime(elapsed: Duration(seconds: 15)));
      now = now.add(const Duration(minutes: 1));
      expect(solvingTime().at(now), const Duration(seconds: 15));

      drillCtrl.continueDrill();
      await _waitFor(() => solvingTime().isRunning);
      expect(solvingTime().at(now), Duration.zero);
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

  test('a Drill can be solved offline once started, its results sent when back online', () async {
    final container = await makeDrillContainer();
    final drillCtrl = container.read(drillControllerProvider.notifier);
    await drillCtrl.start(const DrillConfig(nbPuzzles: 8));

    await _goOffline(container, server);
    for (var i = 0; i < 8; i++) {
      await _solveCurrentPuzzle(container, win: i.isEven);
      drillCtrl.continueDrill();
    }

    var drill = container.read(drillControllerProvider)!;
    expect(drill.isOver, isTrue);
    expect(drill.drill.results, hasLength(8));
    expect(server.solutions, isEmpty);
    expect(drill.drill.ratingAfter, isNull, reason: 'pending');
    // 1500 average puzzle rating, 4 successes out of 8
    expect(drill.drill.performance, 1500, reason: 'known without the server');
    // the solutions sent when the Drill ended stay pending
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(server.solutions, isEmpty);

    await _goOnline(container, server);
    await _waitFor(() => !container.read(drillControllerProvider)!.drill.hasPendingRatingDiff);

    drill = container.read(drillControllerProvider)!;
    expect(server.solutions, hasLength(8));
    expect(drill.drill.ratingAfter, FakeDrillServer.initialRating);
    expect(drill.drill.ratingChange, 0);
  });

  test('the results are sent even if the app misses the connection coming back', () async {
    final container = await makeDrillContainer();
    final drillCtrl = container.read(drillControllerProvider.notifier);
    await drillCtrl.start(const DrillConfig(nbPuzzles: 2));
    // the requests fail, without the app noticing it is offline
    server.isOffline = true;
    for (var i = 0; i < 2; i++) {
      await _solveCurrentPuzzle(container, win: true);
      drillCtrl.continueDrill();
    }
    expect(container.read(drillControllerProvider)!.isOver, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(server.solutions, isEmpty);

    server.isOffline = false;
    await _waitFor(() => !container.read(drillControllerProvider)!.drill.hasPendingRatingDiff);

    expect(server.solutions, hasLength(2));
    expect(container.read(drillControllerProvider)!.drill.ratingChange, 20);
  });

  test('the results of a casual Drill solved offline are sent when back online', () async {
    final container = await makeDrillContainer();
    await container.read(puzzlePreferencesProvider.notifier).setRated(false);
    final drillCtrl = container.read(drillControllerProvider.notifier);
    await drillCtrl.start(const DrillConfig(nbPuzzles: 2));

    await _goOffline(container, server);
    for (var i = 0; i < 2; i++) {
      await _solveCurrentPuzzle(container, win: true);
      drillCtrl.continueDrill();
    }
    expect(container.read(drillControllerProvider)!.isOver, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(server.solutions, isEmpty);

    await _goOnline(container, server);
    await _waitFor(() => server.solutions.length == 2);

    expect(server.solutions.map((s) => s.rated), [false, false]);
  });

  test('the results are sent when back online, even with no puzzle left to download', () async {
    server.nbAvailable = 3;
    final container = await makeDrillContainer();
    final drillCtrl = container.read(drillControllerProvider.notifier);
    await drillCtrl.start(const DrillConfig(nbPuzzles: 3));

    await _goOffline(container, server);
    for (var i = 0; i < 3; i++) {
      await _solveCurrentPuzzle(container, win: true, waitForNext: i < 2);
      drillCtrl.continueDrill();
    }
    expect(container.read(drillControllerProvider)!.isOver, isTrue);

    await _goOnline(container, server);
    await _waitFor(() => !container.read(drillControllerProvider)!.drill.hasPendingRatingDiff);

    expect(server.solutions, hasLength(3));
    expect(container.read(drillControllerProvider)!.drill.ratingChange, 30);
  });

  test('the solutions stay pending while Lichess limits the solving rate', () async {
    final container = await makeDrillContainer();
    final drillCtrl = container.read(drillControllerProvider.notifier);
    await drillCtrl.start(const DrillConfig(nbPuzzles: 3));

    server.isSolveLimited = true;
    for (var i = 0; i < 3; i++) {
      await _solveCurrentPuzzle(container, win: true);
      drillCtrl.continueDrill();
    }

    expect(container.read(drillControllerProvider)!.isOver, isTrue);
    expect(server.nbSolveRequests, 1, reason: 'backed off after the first 429');
    // neither the Drill ending nor the connection coming back sends them while backed off
    await _goOffline(container, server);
    await _goOnline(container, server);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(server.nbSolveRequests, 1);
    expect(container.read(drillControllerProvider)!.drill.ratingAfter, isNull, reason: 'pending');

    // the back-off is over when the player comes back to the app
    server.isSolveLimited = false;
    container
        .read(puzzleSolveLimiterProvider.notifier)
        .markLimitedAt(DateTime.now().subtract(kPuzzleSolveLimitDuration), 1);
    _setAppLifecycleStates(const [.inactive, .hidden, .paused]);
    _setAppLifecycleStates(const [.hidden, .inactive, .resumed]);
    await _waitFor(() => !container.read(drillControllerProvider)!.drill.hasPendingRatingDiff);

    expect(server.solutions, hasLength(3));
    expect(container.read(drillControllerProvider)!.drill.ratingChange, 30);
  });

  test('the pending solutions are kept when a Drill starts at another difficulty', () async {
    final container = await makeDrillContainer();
    final drillCtrl = container.read(drillControllerProvider.notifier);
    await drillCtrl.start(const DrillConfig(nbPuzzles: 2));
    // the requests fail, without the app noticing it is offline
    server.isOffline = true;
    await _solveCurrentPuzzle(container, win: true);
    drillCtrl.continueDrill();
    await _solveCurrentPuzzle(container, win: false);
    drillCtrl.continueDrill();
    expect(container.read(drillControllerProvider)!.isOver, isTrue);

    server.isOffline = false;
    await drillCtrl.start(const DrillConfig(nbPuzzles: 2, difficulty: .hardest));

    expect(server.solutions.map((s) => s.win), [true, false]);
    expect(server.difficulties.last, 'hardest');
  });

  test('a Drill starts at another difficulty while Lichess limits the solving rate', () async {
    final container = await makeDrillContainer();
    final drillCtrl = container.read(drillControllerProvider.notifier);
    await drillCtrl.start(const DrillConfig(nbPuzzles: 2));
    server.isSolveLimited = true;
    await _solveCurrentPuzzle(container, win: true);
    drillCtrl.end();

    final started = await drillCtrl.start(const DrillConfig(nbPuzzles: 2, difficulty: .hardest));

    expect(started, isTrue);
    expect(server.difficulties.last, 'hardest');
    expect(server.nbSolveRequests, 1, reason: 'still backed off');
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

  test('an ended Drill is kept in the Drill History, with its summary', () async {
    final container = await makeDrillContainer();
    final drillCtrl = container.read(drillControllerProvider.notifier);
    await drillCtrl.start(const DrillConfig(nbPuzzles: 2));
    expect(await _history(container), isEmpty);

    await _solveCurrentPuzzle(container, win: true);
    drillCtrl.continueDrill();
    await _solveCurrentPuzzle(container, win: false);
    drillCtrl.continueDrill();
    expect(container.read(drillControllerProvider)!.isOver, isTrue);
    container.dispose();

    final restarted = await makeDrillContainer();
    final history = await _history(restarted);
    expect(history, hasLength(1));
    expect(history.single.config.nbPuzzles, 2);
    expect(history.single.isPartial, isFalse);
    expect(history.single.wins, [true, false]);
    expect(history.single.ratingChange, 0);
  });

  test('the Drill History gets the rating changes synced after the Drill ended', () async {
    final container = await makeDrillContainer();
    final drillCtrl = container.read(drillControllerProvider.notifier);
    await drillCtrl.start(const DrillConfig(nbPuzzles: 2));
    await _goOffline(container, server);
    for (var i = 0; i < 2; i++) {
      await _solveCurrentPuzzle(container, win: true);
      drillCtrl.continueDrill();
    }
    await _waitFor(() => _loadedHistory(container)?.length == 1);
    expect(_loadedHistory(container)!.single.ratingAfter, isNull);

    await _goOnline(container, server);
    await _waitFor(() => _loadedHistory(container)!.single.ratingAfter != null);

    expect(_loadedHistory(container)!.single.ratingChange, 20);
  });

  test('an unfinished Drill ended by starting a new one is kept as a Partial Drill', () async {
    final container = await makeDrillContainer();
    final drillCtrl = container.read(drillControllerProvider.notifier);
    await drillCtrl.start(_drill);
    await _solveCurrentPuzzle(container, win: true);
    drillCtrl.continueDrill();
    // the requests fail, without the app noticing it is offline: the solution is left pending
    server.isOffline = true;
    await _solveCurrentPuzzle(container, win: false);

    server.isOffline = false;
    await drillCtrl.start(const DrillConfig(nbPuzzles: 3));

    final history = await _history(container);
    expect(history, hasLength(1));
    expect(history.single.config, _drill);
    expect(history.single.isPartial, isTrue);
    expect(history.single.wins, [true, false]);
    // the pending solution was sent as the new Drill started
    final drill = await container.read(drillHistoryDrillProvider(history.single.startedAt).future);
    expect(drill!.results.map((r) => r.ratingDiff), [10, -10]);
    expect(history.single.ratingChange, 0);
  });

  test('a Drill ended before any puzzle is solved is not kept', () async {
    final container = await makeDrillContainer();
    final drillCtrl = container.read(drillControllerProvider.notifier);
    await drillCtrl.start(_drill);
    drillCtrl.end();
    await drillCtrl.start(_drill);
    await drillCtrl.start(_drill);

    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(await _history(container), isEmpty);
  });

  test('each account has its own Drill History, kept while signed out', () async {
    final container = await makeDrillContainer();
    await _playDrill(container, nbPuzzles: 1);
    expect(await _history(container), hasLength(1));

    await container.read(authControllerProvider.notifier).signOut();
    expect(await _history(container), isEmpty);
    container.dispose();

    final other = await makeDrillContainer(authUser: _otherAuthUser);
    expect(await _history(other), isEmpty);
    await _playDrill(other, nbPuzzles: 2);
    await _playDrill(other, nbPuzzles: 3);
    expect(await _history(other), hasLength(2));
    other.dispose();

    final back = await makeDrillContainer();
    final history = await _history(back);
    expect(history.map((d) => d.config.nbPuzzles), [1]);
  });

  test('the Drill History lists the Drills newest first, and a Drill can be deleted', () async {
    var now = DateTime(2026, 10, 21, 9);
    await withClock(Clock(() => now), () async {
      final container = await makeDrillContainer();
      for (final nbPuzzles in [1, 2, 3]) {
        await _playDrill(container, nbPuzzles: nbPuzzles);
        now = now.add(const Duration(hours: 1));
      }

      final history = await _history(container);
      expect(history.map((d) => d.config.nbPuzzles), [3, 2, 1]);
      expect(history.map((d) => d.startedAt.hour), [11, 10, 9]);

      await container.read(drillHistoryProvider.notifier).delete(history[1].startedAt);

      expect(_loadedHistory(container)!.map((d) => d.config.nbPuzzles), [3, 1]);
      container.dispose();
      final restarted = await makeDrillContainer();
      final kept = await _history(restarted);
      expect(kept.map((d) => d.config.nbPuzzles), [3, 1]);
    });
  });

  test('a deleted Drill stays deleted when its rating changes come', () async {
    final container = await makeDrillContainer();
    final drillCtrl = container.read(drillControllerProvider.notifier);
    await drillCtrl.start(const DrillConfig(nbPuzzles: 1));
    await _goOffline(container, server);
    await _solveCurrentPuzzle(container, win: true);
    drillCtrl.continueDrill();
    await _waitFor(() => _loadedHistory(container)?.length == 1);

    await container
        .read(drillHistoryProvider.notifier)
        .delete(_loadedHistory(container)!.single.startedAt);
    await _goOnline(container, server);
    await _waitFor(() => !container.read(drillControllerProvider)!.drill.hasPendingRatingDiff);

    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(await _history(container), isEmpty);
  });

  test('the Drill History is loaded a page at a time, whole days at once', () async {
    final container = await makeDrillContainer();
    final history = container.read(drillHistoryProvider.notifier);
    // 4 Drills a day for 17 days, then 3 more: 71 Drills
    for (var i = 0; i < 71; i++) {
      await history.add(_userId, _pastDrill(DateTime(2026, 9, 1 + i ~/ 4, 8 + i % 4)));
    }
    container.invalidate(drillHistoryProvider);

    var loaded = await container.read(drillHistoryProvider.future);
    // 30, and the other Drill of the day of the 30th
    expect(loaded.entries, hasLength(31));
    expect(loaded.entries.first.startedAt, DateTime(2026, 9, 18, 10));
    expect(loaded.hasMore, isTrue);

    await history.loadMore();
    loaded = container.read(drillHistoryProvider).value!;
    expect(loaded.entries, hasLength(63));
    expect(loaded.hasMore, isTrue);

    await history.loadMore();
    loaded = container.read(drillHistoryProvider).value!;
    expect(loaded.entries, hasLength(71));
    expect(loaded.entries.last.startedAt, DateTime(2026, 9, 1, 8));
    expect(loaded.hasMore, isFalse);
  });

  test('the Drills kept before the summaries existed are listed with them', () async {
    final directory = await Directory.systemTemp.createTemp('drills_test');
    addTearDown(() => directory.delete(recursive: true));
    final path = join(directory.path, 'drills.db');
    final drill = _pastDrill(DateTime(2026, 10, 21, 22, 36));
    final v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => db.execute(
          'CREATE TABLE drill_history(userId TEXT NOT NULL, startedAt TEXT NOT NULL, '
          'data TEXT NOT NULL, PRIMARY KEY (userId, startedAt))',
        ),
      ),
    );
    await v1.insert('drill_history', {
      'userId': _userId.value,
      'startedAt': drill.startedAt.toUtc().toIso8601String(),
      'data': jsonEncode(drill.toJson()),
    });
    await v1.close();
    await drillDatabase.close();
    drillDatabase = await openDrillDatabase(databaseFactoryFfi, path);

    final container = await makeDrillContainer();

    final entry = (await _history(container)).single;
    expect(entry.startedAt, drill.startedAt);
    expect(entry.wins, [true, false, true, true, false]);
    expect(entry.ratingChange, 10);
    final points = await container.read(drillChartPointsProvider.future);
    expect(points.single.performance, 1600);
  });

  test("a Drill's expected share of puzzles solved is from its puzzles' ratings", () async {
    server.puzzleRatingOf = (index) => index == 0 ? 1500 : 1900;
    final container = await makeDrillContainer();
    final drillCtrl = container.read(drillControllerProvider.notifier);
    await drillCtrl.start(const DrillConfig(nbPuzzles: 2));
    for (var i = 0; i < 2; i++) {
      await _solveCurrentPuzzle(container, win: true);
      drillCtrl.continueDrill();
    }

    final drill = container.read(drillControllerProvider)!.drill;
    // 50 % for the puzzle at the player's 1500, 9 % for the one 400 points above
    expect(drill.expectedSuccessRate, closeTo(0.2955, 0.0001));
    await _waitFor(() => _loadedHistory(container)?.length == 1);
    expect(_loadedHistory(container)!.single.expectedSuccessRate, closeTo(0.2955, 0.0001));
  });

  test('the chart has the values of every Drill, oldest first', () async {
    final container = await makeDrillContainer();
    final history = container.read(drillHistoryProvider.notifier);
    await history.add(_userId, _pastDrill(DateTime(2026, 10, 20)));
    await history.add(_userId, _pastDrill(DateTime(2026, 10, 21), rated: false));

    final points = await container.read(drillChartPointsProvider.future);

    expect(points.map((p) => p.startedAt), [DateTime(2026, 10, 20), DateTime(2026, 10, 21)]);
    // 1500 average puzzle rating, 3 successes out of 5
    expect(points.map((p) => p.performance), [1600, 1600]);
    expect(points.map((p) => p.successRate), [0.6, 0.6]);
    expect(points.map((p) => p.expectedSuccessRate), [0.5, 0.5]);
    expect(points.map((p) => p.ratingAfter), [1510, null], reason: 'a casual Drill');
    expect(points.map((p) => p.isPerformanceReliable), [false, false]);
  });
}

/// Plays a whole Drill of [nbPuzzles], all of them solved, and waits for it to be kept in the
/// Drill History.
Future<void> _playDrill(ProviderContainer container, {required int nbPuzzles}) async {
  final drillCtrl = container.read(drillControllerProvider.notifier);
  final nbKept = (await _history(container)).length;
  await drillCtrl.start(DrillConfig(nbPuzzles: nbPuzzles));
  for (var i = 0; i < nbPuzzles; i++) {
    await _solveCurrentPuzzle(container, win: true);
    drillCtrl.continueDrill();
  }
  await _waitFor(() => _loadedHistory(container)?.length == nbKept + 1);
}

/// An ended Drill of 5 puzzles at 1500 started at [startedAt] by a player at 1500, with 3
/// successes: +10 for each, −10 for each failure, when [rated].
Drill _pastDrill(DateTime startedAt, {bool rated = true}) {
  const wins = [true, false, true, true, false];
  return Drill(
    config: const DrillConfig(nbPuzzles: 5),
    startedAt: startedAt,
    ratingBefore: 1500,
    latestRating: rated ? 1510 : 1500,
    results: [
      for (final (i, win) in wins.indexed)
        DrillPuzzleResult(
          id: PuzzleId('past$i'),
          puzzleRating: 1500,
          themes: const ISetConst({}),
          win: win,
          rated: rated,
          solvingTime: const Duration(seconds: 10),
          ratingDiff: rated ? (win ? 10 : -10) : null,
        ),
    ].toIList(),
  );
}

/// The summaries of the Drills of the Drill History, once loaded.
Future<IList<DrillHistoryEntry>> _history(ProviderContainer container) async =>
    (await container.read(drillHistoryProvider.future)).entries;

/// The summaries of the Drills of the Drill History loaded so far, if any.
IList<DrillHistoryEntry>? _loadedHistory(ProviderContainer container) =>
    container.read(drillHistoryProvider).value?.entries;

PuzzleState _puzzleState(ProviderContainer container) => container.read(
  puzzleControllerProvider(container.read(drillControllerProvider)!.puzzleContext),
);

PuzzleController _puzzleCtrl(ProviderContainer container) => container.read(
  puzzleControllerProvider(container.read(drillControllerProvider)!.puzzleContext).notifier,
);

/// Solves the puzzle the Drill is on, waiting for its result to be sent to the server.
///
/// It is won by playing the solution, or lost by viewing the solution. With [hint], a hint is asked
/// for first, which fails it even if the solution is then played. [whilePlaying] is called once the
/// player can move, before the puzzle is solved. Without [waitForNext], when no puzzle is left to
/// play, it only waits for the solution to be saved.
Future<void> _solveCurrentPuzzle(
  ProviderContainer container, {
  required bool win,
  bool hint = false,
  bool waitForNext = true,
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
  if (hint) puzzleCtrl.showHintAsFailure();
  if (win) {
    for (final move in FakeDrillServer.playerMoves) {
      await puzzleCtrl.onUserMove(move);
    }
  } else {
    puzzleCtrl.viewSolution();
  }
  if (!waitForNext) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return;
  }
  // the solution is sent and the next puzzle prepared, or already loaded with auto-next
  await _waitFor(() {
    final state = container.read(ctrlProvider);
    return state.nextContext != null || state.puzzle.puzzle.id != puzzleId;
  });
}

void _setAppLifecycleStates(List<AppLifecycleState> states) =>
    states.forEach(TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged);

/// Takes the device offline, waiting for the app to notice.
Future<void> _goOffline(ProviderContainer container, FakeDrillServer server) =>
    _setDeviceOnline(container, server, false);

/// Brings the device back online, waiting for the app to notice.
Future<void> _goOnline(ProviderContainer container, FakeDrillServer server) =>
    _setDeviceOnline(container, server, true);

Future<void> _setDeviceOnline(
  ProviderContainer container,
  FakeDrillServer server,
  bool isOnline,
) async {
  server.isOffline = !isOnline;
  await container.read(connectivityChangesProvider.future);
  FakeConnectivity.controller.add([if (isOnline) .wifi else .none]);
  await _waitFor(() => container.read(isDeviceOnlineProvider) == isOnline);
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
