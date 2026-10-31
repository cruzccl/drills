import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/drill/drill_controller.dart';
import 'package:lichess_mobile/src/model/drill/drill_group.dart';
import 'package:lichess_mobile/src/model/drill/drill_history.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_angle.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_difficulty.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_theme.dart';

void main() {
  group('DrillGroup', () {
    test('takes the puzzles of its Drills as one Drill, each counting the same', () {
      final group = DrillGroup(
        [
          _drill(ratingBefore: 1500, results: [(1500, true), (1700, false)]),
          _drill(ratingBefore: 1600, results: [(1600, true), (1600, true), (1400, true)]),
        ].lock,
      );
      final all = _drill(
        ratingBefore: 1500,
        results: [(1500, true), (1700, false), (1600, true), (1600, true), (1400, true)],
      );

      expect(group.nbPlayed, 5);
      expect(group.successes, 4);
      expect(group.successRate, 0.8);
      expect(group.performance, all.performance);
      expect(group.isPerformanceReliable, isFalse);
      expect(group.totalSolvingTime, const Duration(seconds: 50));
      expect(group.averageSolvingTime, const Duration(seconds: 10));
    });

    test('expects each puzzle to be solved against the rating its own Drill started at', () {
      final group = DrillGroup(
        [
          _drill(ratingBefore: 1500, results: [(1500, true)]),
          _drill(ratingBefore: 1900, results: [(1500, true)]),
        ].lock,
      );

      expect(
        group.expectedSuccessRate,
        closeTo((expectedPuzzleScore(1500, 1500) + expectedPuzzleScore(1900, 1500)) / 2, 1e-9),
      );
      expect(
        DrillGroup(
          [
            _drill(ratingBefore: 1500, results: [(1500, true)]),
            _drill(ratingBefore: null, results: [(1500, true)]),
          ].lock,
        ).expectedSuccessRate,
        isNull,
      );
    });

    test('sums the rating changes, once every one is known', () {
      final drills = [
        _drill(ratingBefore: 1500, results: [(1500, true), (1500, false)]),
        _drill(ratingBefore: 1500, results: [(1500, true)]),
      ];
      expect(DrillGroup(drills.lock).ratingChange, 10);

      final pending = _drill(ratingBefore: 1500, results: [(1500, true)]).copyWith(
        results: [
          const DrillPuzzleResult(
            id: PuzzleId('pending'),
            puzzleRating: 1500,
            themes: ISetConst({}),
            win: true,
            rated: true,
            solvingTime: Duration(seconds: 10),
          ),
        ].lock,
      );
      expect(DrillGroup([...drills, pending].lock).ratingChange, isNull);
    });

    test('groups only two Drills or more of the same theme and difficulty', () {
      const normal = DrillConfig(nbPuzzles: 10);
      expect(DrillGroup.canBeGrouped([normal]), isFalse);
      expect(DrillGroup.canBeGrouped([normal, const DrillConfig(nbPuzzles: 20)]), isTrue);
      expect(
        DrillGroup.canBeGrouped([
          normal,
          const DrillConfig(nbPuzzles: 10, difficulty: PuzzleDifficulty.harder),
        ]),
        isFalse,
      );
      expect(
        DrillGroup.canBeGrouped([
          normal,
          const DrillConfig(nbPuzzles: 10, angle: PuzzleTheme(PuzzleThemeKey.fork)),
        ]),
        isFalse,
      );
    });
  });

  group('drillGroupChoicesOf', () {
    test('groups the Drills by theme and difficulty, those that can be analyzed first', () {
      const fork = PuzzleTheme(PuzzleThemeKey.fork);
      final mixOld = _entry(day: 1, wins: [true, true]);
      final mixPartial = _entry(day: 2, wins: [false], nbPuzzles: 10);
      final forkOld = _entry(day: 3, wins: [true, false, true], angle: fork);
      final harder = _entry(day: 4, wins: [true, true, true, true, true], difficulty: .harder);
      final forkNew = _entry(day: 5, wins: [false], angle: fork);

      final choices = drillGroupChoicesOf([mixOld, mixPartial, forkOld, harder, forkNew]);

      expect(choices.map((c) => c.entries.toList()), [
        [forkNew, forkOld],
        [mixPartial, mixOld],
        [harder],
      ], reason: 'the most puzzles first, the Drill alone last, each group newest first');
      expect(choices.map((c) => c.canBeAnalyzed), [true, true, false]);
      expect(choices[1].nbDrills, 2);
      expect(choices[1].nbPlayed, 3, reason: 'a Partial Drill counts its puzzles played');
      expect(choices[1].successRate, closeTo(2 / 3, 1e-9));
      expect(choices[1].startedAts.unlock, {mixOld.startedAt, mixPartial.startedAt});
    });

    test('is empty without Drills', () {
      expect(drillGroupChoicesOf([]), isEmpty);
    });
  });

  group('drillDaysOf', () {
    final today = DateTime(2026, 10, 31, 15, 30);

    test('counts today in the days of a range', () {
      expect(drillDaysOf(.week, today: today), (
        first: DateTime(2026, 10, 25),
        last: DateTime(2026, 10, 31),
      ));
      expect(drillDaysOf(.month, today: today).first, DateTime(2026, 10, 2));
    });

    test('starts the whole Drill History at its first Drill', () {
      expect(drillDaysOf(.all, today: today), (first: null, last: DateTime(2026, 10, 31)));
    });
  });
}

var _nbDrills = 0;

/// An ended Drill of the puzzles of [results], each a puzzle rating and whether it was solved,
/// changing the rating by 10 and solved in 10 seconds.
Drill _drill({required int? ratingBefore, required List<(int, bool)> results}) {
  final n = _nbDrills++;
  return Drill(
    config: DrillConfig(nbPuzzles: results.length),
    startedAt: DateTime(2026, 10, 20, n),
    ratingBefore: ratingBefore,
    results: [
      for (final (i, (rating, win)) in results.indexed)
        DrillPuzzleResult(
          id: PuzzleId('d${n}p$i'),
          puzzleRating: rating,
          themes: const ISetConst({}),
          win: win,
          rated: true,
          solvingTime: const Duration(seconds: 10),
          ratingDiff: win ? 10 : -10,
        ),
    ].lock,
  );
}

/// The summary of an ended Drill started on day [day] of October 2026, solving the puzzles of
/// [wins] out of [nbPuzzles], all of them by default.
DrillHistoryEntry _entry({
  required int day,
  required List<bool> wins,
  int? nbPuzzles,
  PuzzleAngle angle = const PuzzleTheme(PuzzleThemeKey.mix),
  PuzzleDifficulty difficulty = .normal,
}) => DrillHistoryEntry(
  config: DrillConfig(nbPuzzles: nbPuzzles ?? wins.length, angle: angle, difficulty: difficulty),
  startedAt: DateTime(2026, 10, day, 9),
  wins: wins.lock,
);
