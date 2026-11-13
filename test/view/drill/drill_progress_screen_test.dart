import 'dart:math' as math;

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/drill/drill_controller.dart';
import 'package:lichess_mobile/src/model/drill/drill_history.dart';
import 'package:lichess_mobile/src/view/drill/drill_progress_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../model/auth/fake_auth_storage.dart';
import '../../test_provider_scope.dart';

/// The Progress screen of [fakeAuthUser], with a Drill of 2 puzzles on each of [days] before
/// today, on the range named [range].
Future<void> _openProgress(
  WidgetTester tester, {
  required List<int> days,
  required String range,
}) async {
  await tester.pumpWidget(
    await makeTestProviderScopeApp(
      tester,
      home: const DrillProgressScreen(),
      authUser: fakeAuthUser,
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(tester.element(find.byType(DrillProgressScreen)));
  final history = container.read(drillHistoryProvider.notifier);
  final today = DateUtils.dateOnly(DateTime.now());
  for (final day in days) {
    await history.add(
      fakeAuthUser.user.id,
      _drill(_addDays(today, -day).add(const Duration(hours: 9))),
    );
  }
  await tester.pumpAndSettle();
  await tester.tap(find.text(range));
  await tester.pumpAndSettle();
}

DateTime _addDays(DateTime day, int nbDays) => DateTime(day.year, day.month, day.day + nbDays);

/// The line below the calendar with the Drills and puzzles of the days chosen.
Finder _chosenDays(Pattern text) => find.textContaining(text, findRichText: true);

void main() {
  testWidgets('a day touched shows its Drills, a second one those of the days between', (
    tester,
  ) async {
    await _openProgress(tester, days: [100, 2, 1], range: '1M');
    final today = DateUtils.dateOnly(DateTime.now());
    // The day numbers come after the numbers of the streak, which may be the same.
    Finder dayNumber(int nbDaysAgo) => find.text('${_addDays(today, -nbDaysAgo).day}').last;

    expect(_chosenDays(RegExp('Drills? · |No Drills')), findsNothing);

    await tester.tap(dayNumber(2));
    await tester.pumpAndSettle();
    expect(_chosenDays('1 Drill · 2 puzzles'), findsOneWidget);

    await tester.tap(dayNumber(0));
    await tester.pumpAndSettle();
    expect(_chosenDays('2 Drills · 4 puzzles'), findsOneWidget);

    await tester.tap(dayNumber(0));
    await tester.pumpAndSettle();
    expect(_chosenDays('No Drills'), findsOneWidget, reason: 'a third day chosen alone');

    await tester.tap(dayNumber(0));
    await tester.pumpAndSettle();
    expect(_chosenDays('No Drills'), findsNothing, reason: 'the day alone let go');
  });

  testWidgets('a finger pressed on the heatmap shows the day under it, chosen once lifted', (
    tester,
  ) async {
    await _openProgress(tester, days: [100, 1], range: '3M');
    final today = DateUtils.dateOnly(DateTime.now());
    final yesterday = _addDays(today, -1);
    // The place of a day on the heatmap of the last 91 days, a column per week from Monday.
    final rect = tester.getRect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter.runtimeType.toString() == '_HeatmapPainter',
      ),
    );
    final start = _addDays(today, -90);
    final first = _addDays(start, -(start.weekday - DateTime.monday));
    final nbWeeks = today.difference(first).inDays ~/ 7 + 1;
    final gap = rect.width / nbWeeks > 6.0 ? 2.0 : 1.0;
    final cell = math.min(14.0, (rect.width - gap * (nbWeeks - 1)) / nbWeeks);
    Offset centerOf(DateTime day) {
      final index = DateTime.utc(
        day.year,
        day.month,
        day.day,
      ).difference(DateTime.utc(first.year, first.month, first.day)).inDays;
      return rect.topLeft +
          Offset((index ~/ 7) * (cell + gap) + cell / 2, (index % 7) * (cell + gap) + cell / 2);
    }

    final gesture = await tester.startGesture(centerOf(today));
    await tester.pump();
    expect(find.text(DateFormat.yMMMEd().format(today)), findsOneWidget);
    expect(find.text('No Drills'), findsOneWidget);

    await gesture.moveTo(centerOf(yesterday));
    await tester.pump();
    expect(find.text(DateFormat.yMMMEd().format(yesterday)), findsOneWidget);
    expect(find.text('2 puzzles'), findsOneWidget);
    expect(_chosenDays('1 Drill · '), findsNothing, reason: 'not chosen while pressed');

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text(DateFormat.yMMMEd().format(yesterday)), findsNothing);
    expect(_chosenDays('1 Drill · 2 puzzles'), findsOneWidget);
  });
}

/// An ended Drill of 2 puzzles started at [startedAt].
Drill _drill(DateTime startedAt) => Drill(
  config: const DrillConfig(nbPuzzles: 2),
  startedAt: startedAt,
  ratingBefore: 1500,
  latestRating: 1500,
  results: [
    for (final (i, win) in [true, false].indexed)
      DrillPuzzleResult(
        id: PuzzleId('p${startedAt.day}$i'),
        puzzleRating: 1500,
        themes: const ISetConst({}),
        win: win,
        rated: true,
        solvingTime: const Duration(seconds: 10),
        ratingDiff: win ? 10 : -10,
      ),
  ].toIList(),
);
