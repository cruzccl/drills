import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lichess_mobile/src/model/drill/drill_controller.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_controller.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_difficulty.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_preferences.dart';
import 'package:lichess_mobile/src/network/http.dart';
import 'package:lichess_mobile/src/service/puzzle_service.dart';

import '../../network/fake_http_client_factory.dart';
import '../../test_container.dart';
import '../auth/fake_auth_storage.dart';
import 'fake_drill_server.dart';

void main() {
  late FakeDrillServer server;

  setUp(() => server = FakeDrillServer());

  Future<ProviderContainer> makeDrillContainer() => makeContainer(
    authUser: fakeAuthUser,
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
    expect(drill.successes, 3);
    expect(drill.failures, 2);
    expect(drill.successRate, 0.6);
    expect(server.solutions.map((s) => s.win), [true, false, true, true, false]);
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
    expect(drill.successes, 4);
    expect(drill.failures, 1);
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
}

/// Solves the puzzle the Drill is on, waiting for its result to be sent to the server.
///
/// It is won by playing the solution, or lost by viewing the solution.
Future<void> _solveCurrentPuzzle(
  ProviderContainer container, {
  required bool win,
  bool hint = false,
}) async {
  final ctrlProvider = puzzleControllerProvider(
    container.read(drillControllerProvider)!.puzzleContext,
  );
  final puzzleCtrl = container.read(ctrlProvider.notifier);
  final puzzleId = container.read(ctrlProvider).puzzle.puzzle.id;

  // the opponent's move is played after 1 second
  await _waitFor(() => container.read(ctrlProvider).mode == .play);
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
