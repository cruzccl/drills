import 'dart:convert';

import 'package:chessground/chessground.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lichess_mobile/src/app.dart';
import 'package:lichess_mobile/src/model/drill/drill_controller.dart';
import 'package:lichess_mobile/src/model/drill/drill_preferences.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_angle.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_difficulty.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_theme.dart';
import 'package:lichess_mobile/src/model/settings/preferences_storage.dart';
import 'package:lichess_mobile/src/network/connectivity.dart';
import 'package:lichess_mobile/src/network/http.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/view/analysis/analysis_screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_screen.dart';
import 'package:lichess_mobile/src/view/engine/engine_button.dart';
import 'package:lichess_mobile/src/view/puzzle/puzzle_session_widget.dart';
import 'package:lichess_mobile/src/widgets/bottom_bar.dart';
import 'package:lichess_mobile/src/widgets/non_linear_slider.dart';
import 'package:material_ui/material_ui.dart';

import '../../model/auth/fake_auth_storage.dart';
import '../../model/drill/fake_drill_server.dart';
import '../../network/fake_http_client_factory.dart';
import '../../test_helpers.dart';
import '../../test_provider_scope.dart';
import '../../utils/fake_connectivity.dart';

void main() {
  late FakeDrillServer server;

  setUp(() => server = FakeDrillServer());

  Future<void> openHome(
    WidgetTester tester, {
    required bool signedIn,
    Map<String, Object>? defaultPreferences,
  }) async {
    final app = await makeTestProviderScope(
      tester,
      child: const Application(),
      authUser: signedIn ? fakeAuthUser : null,
      defaultPreferences: defaultPreferences,
      overrides: {
        httpClientFactoryProvider: httpClientFactoryProvider.overrideWith(
          (ref) => FakeHttpClientFactory(() => server.client),
        ),
      },
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  testWidgets('signed out, the home screen only offers to sign in', (tester) async {
    await openHome(tester, signedIn: false);

    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    expect(find.text('Empezar'), findsNothing);
  });

  testWidgets('plays a Drill showing only its progress, then its summary', (tester) async {
    await openHome(tester, signedIn: true);

    await tester.tap(find.widgetWithText(ChoiceChip, '5'));
    await tester.tap(find.text('Empezar'));
    // load the puzzles and open the Drill
    await tester.pumpAndSettle();
    expect(find.byType(DrillScreen), findsOneWidget);
    expect(find.text('1 / 5'), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsNothing, reason: 'the clock is off by default');

    // wait for the opponent's move, then play the solution
    await tester.pump(const Duration(milliseconds: 1500));
    await playMove(tester, 'g4', 'h4', orientation: Side.black);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await playMove(tester, 'b4', 'h4', orientation: Side.black);
    await tester.pumpAndSettle();

    // the puzzle's own feedback is shown, but not the player's rating, the result strip of the
    // previous puzzles, nor the Drill's score
    expect(find.text('Success!'), findsOneWidget);
    expect(find.text('1 / 5'), findsOneWidget);
    expect(find.text('Rating'), findsNothing);
    expect(find.byType(PuzzleSessionWidget), findsNothing);
    expect(find.textContaining('Aciertos'), findsNothing);

    await tester.tap(find.byIcon(CupertinoIcons.play_arrow_solid));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('2 / 5'), findsOneWidget);

    // fail the remaining puzzles by viewing their solution, once it is offered
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.byIcon(Icons.flag_outlined));
      // the solution is replayed and the next arrow blinks: no pumpAndSettle
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byIcon(CupertinoIcons.play_arrow_solid));
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(Chessboard), findsNothing);
    expect(server.solutions.map((s) => s.win), [true, false, false, false, false]);
    await tester.pumpAndSettle();
    expect(find.text('5 problemas · Healthy mix · Normal'), findsOneWidget);
    expect(_summaryValue('Aciertos'), '1');
    expect(_summaryValue('Fallos'), '4');
    expect(_summaryValue('Porcentaje de aciertos'), '20 %');
    // from the puzzles' 1500 and the player's 1500
    expect(find.text('Esperado 50 %'), findsOneWidget);
    expect(_summaryValue('Puntuación'), '1500 → 1470 (−30)');
    // 1500 average puzzle rating, 1 success out of 5
    expect(_summaryValue('Rendimiento'), '1200');
    expect(find.text('Poco fiable'), findsOneWidget);
    expect(find.text('Endgame (4)'), findsOneWidget);
    expect(find.text('Fork (4)'), findsOneWidget);
    expect(find.text('Short (4)'), findsNothing, reason: 'a length theme');

    // the puzzles of the Drill, each opened on the analysis board
    await tester.scrollUntilVisible(find.text('+10').hitTestable(), 200.0);
    expect(find.text('−10'), findsWidgets);
    await tester.tap(find.text('+10'));
    await tester.pumpAndSettle();
    expect(find.byType(AnalysisScreen), findsOneWidget);
  });

  testWidgets('with the clock on, the time spent on the puzzle ticks until its result', (
    tester,
  ) async {
    await openHome(
      tester,
      signedIn: true,
      defaultPreferences: {
        PrefCategory.drillSettings.storageKey: jsonEncode(
          const DrillPrefs(showClock: true).toJson(),
        ),
      },
    );

    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();
    // wait for the opponent's move: the player can move
    await tester.pump(const Duration(milliseconds: 1500));
    final timeWhenPlaying = _clockSeconds(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(_clockSeconds(tester), timeWhenPlaying + 3);

    await _failCurrentPuzzle(tester);
    final timeAtResult = _clockSeconds(tester);
    await tester.pump(const Duration(seconds: 5));
    expect(_clockSeconds(tester), timeAtResult, reason: 'stopped at the result');
    expect(_clockColor(tester), tester.element(_clock()).lichessColors.error);

    await tester.tap(find.byIcon(CupertinoIcons.play_arrow_solid));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(_clockSeconds(tester), lessThan(2), reason: 'the next puzzle is timed from zero');
  });

  testWidgets('a Drill ended early shows its summary, marked as partial', (tester) async {
    await openHome(tester, signedIn: true);
    await tester.tap(find.widgetWithText(ChoiceChip, '5'));
    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();

    await _failCurrentPuzzle(tester);
    await tester.tap(find.byIcon(CupertinoIcons.play_arrow_solid));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('2 / 5'), findsOneWidget);

    await tester.tap(find.text('Terminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('5 problemas · Healthy mix · Normal · Incompleto'), findsOneWidget);
    expect(_summaryValue('Fallos'), '1');
  });

  testWidgets('the Drill Summary shows the rating as pending until it is synced', (tester) async {
    await openHome(tester, signedIn: true);
    await tester.tap(find.widgetWithText(ChoiceChip, '5'));
    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();

    server.isOffline = true;
    FakeConnectivity.controller.add([.none]);
    await _failCurrentPuzzle(tester);
    await tester.tap(find.byIcon(CupertinoIcons.play_arrow_solid));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Terminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(_summaryValue('Puntuación'), '1500 → pendiente');
    expect(_summaryValue('Rendimiento'), '1000', reason: 'known without the server');
    await tester.scrollUntilVisible(find.text('pendiente').last, 200.0);

    server.isOffline = false;
    // past the throttling of connectivity changes
    await tester.pump(kConnectivityThrottleDelay);
    FakeConnectivity.controller.add([.wifi]);
    await tester.pumpAndSettle();

    expect(find.text('pendiente'), findsNothing);
    expect(find.text('−10'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Puntuación'), -200.0);
    expect(_summaryValue('Puntuación'), '1500 → 1490 (−10)');
  });

  testWidgets('a Drill ended before any puzzle is solved goes back home', (tester) async {
    await openHome(tester, signedIn: true);
    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Terminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.byType(DrillScreen), findsNothing);
    expect(find.text('Empezar'), findsOneWidget);
    expect(find.textContaining('Reanudar'), findsNothing);
  });

  testWidgets('the home screen offers to resume an unfinished Drill', (tester) async {
    await openHome(tester, signedIn: true);
    await tester.tap(find.widgetWithText(ChoiceChip, '5'));
    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();
    await _failCurrentPuzzle(tester);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('1 / 5 · Healthy mix · Normal'), findsOneWidget);

    await tester.tap(find.text('Reanudar el Drill'));
    // the next arrow of the failed puzzle blinks: no pumpAndSettle
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(DrillScreen), findsOneWidget);
    expect(find.text('1 / 5'), findsOneWidget, reason: 'still on the failed puzzle');

    // starting a new Drill instead asks first
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();
    expect(find.byType(DrillScreen), findsNothing);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 5'), findsOneWidget);
    expect(find.byType(DrillScreen), findsOneWidget);
  });

  testWidgets('a Drill is set up with a number of puzzles, a theme and a difficulty', (
    tester,
  ) async {
    await openHome(tester, signedIn: true);
    expect(_isChipSelected(tester, '10'), isTrue, reason: 'the default number of puzzles');
    expect(find.text('Healthy mix'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '12'));
    await tester.pump();
    expect(_isChipSelected(tester, '12'), isTrue);
    expect(_isChipSelected(tester, '10'), isFalse);

    await tester.tap(find.text('Tema'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Motifs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fork'));
    await tester.pumpAndSettle();
    expect(find.text('Fork'), findsOneWidget);

    await tester.tap(find.text('Difficulty level'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hardest'));
    await tester.pumpAndSettle();
    expect(find.text('Hardest'), findsOneWidget);

    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 12'), findsOneWidget);
    expect(server.angles.toSet(), {'fork'});
    expect(server.difficulties.toSet(), {'hardest'});
  });

  testWidgets('a Drill can be set up on an opening', (tester) async {
    await openHome(tester, signedIn: true);

    await tester.tap(find.text('Tema'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('By openings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sicilian Defense'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Najdorf Variation'));
    await tester.pumpAndSettle();
    expect(find.text('Sicilian Defense: Najdorf Variation'), findsOneWidget);

    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 10'), findsOneWidget);
    expect(server.angles.toSet(), {'Sicilian_Defense_Najdorf_Variation'});
  });

  testWidgets('the number of puzzles is set with a slider, from 1 to 50', (tester) async {
    await openHome(tester, signedIn: true);
    expect(_sliderValue(tester), 10);

    await tester.tap(find.widgetWithText(ChoiceChip, '12'));
    await tester.pump();
    expect(_sliderValue(tester), 12, reason: 'a quick pick moves the slider');

    await tester.drag(find.byType(Slider), const Offset(-1000, 0));
    await tester.pumpAndSettle();
    expect(_sliderValue(tester), 1);
    expect(find.text('1'), findsOneWidget, reason: 'the number of puzzles is shown');
    expect(_isChipSelected(tester, '12'), isFalse);

    await tester.drag(find.byType(Slider), const Offset(1000, 0));
    await tester.pumpAndSettle();
    expect(_sliderValue(tester), 50);

    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 50'), findsOneWidget);
  });

  testWidgets('the last configuration is preselected', (tester) async {
    await openHome(
      tester,
      signedIn: true,
      defaultPreferences: {
        SessionPreferencesStorage.key(PrefCategory.drill.storageKey, fakeAuthUser): jsonEncode(
          const DrillConfig(
            nbPuzzles: 37,
            angle: PuzzleTheme(PuzzleThemeKey.fork),
            difficulty: PuzzleDifficulty.easier,
          ).toJson(),
        ),
      },
    );

    expect(_sliderValue(tester), 37);
    expect(find.text('37'), findsOneWidget);
    expect(find.text('Fork'), findsOneWidget);
    expect(find.text('Easier'), findsOneWidget);

    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 37'), findsOneWidget);
    expect(server.angles.toSet(), {'fork'});
    expect(server.difficulties.toSet(), {'easier'});
  });

  testWidgets('the puzzle just solved is opened on the analysis board, then the Drill goes on', (
    tester,
  ) async {
    await openHome(
      tester,
      signedIn: true,
      defaultPreferences: {
        SessionPreferencesStorage.key(PrefCategory.drill.storageKey, fakeAuthUser): jsonEncode(
          const DrillConfig(nbPuzzles: 2).toJson(),
        ),
        PrefCategory.drillSettings.storageKey: jsonEncode(
          const DrillPrefs(showClock: true).toJson(),
        ),
      },
    );
    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.byIcon(Icons.biotech), findsNothing, reason: 'not while the puzzle is solved');

    await _failCurrentPuzzle(tester);
    final timeAtResult = _clockSeconds(tester);
    await tester.tap(find.byIcon(Icons.biotech));
    await tester.pumpAndSettle();
    expect(find.byType(AnalysisScreen), findsOneWidget);
    expect(find.byIcon(Icons.crisis_alert), findsOneWidget, reason: 'the Drill analysis board');
    await tester.pump(const Duration(seconds: 5));

    await tester.pageBack();
    // the next arrow still blinks: no pumpAndSettle
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(AnalysisScreen), findsNothing);
    expect(find.byType(DrillScreen), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(_clockSeconds(tester), timeAtResult, reason: 'the time stays at the result');
    await tester.tap(find.byIcon(CupertinoIcons.play_arrow_solid));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets("a Drill puzzle's analysis board shows the threat instead of the menu", (
    tester,
  ) async {
    await openHome(
      tester,
      signedIn: true,
      defaultPreferences: {
        SessionPreferencesStorage.key(PrefCategory.drill.storageKey, fakeAuthUser): jsonEncode(
          const DrillConfig(nbPuzzles: 1).toJson(),
        ),
      },
    );
    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();
    await _failCurrentPuzzle(tester);
    await tester.tap(find.byIcon(CupertinoIcons.play_arrow_solid));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('−10').hitTestable(), 200.0);
    await tester.tap(find.text('−10'));
    await tester.pumpAndSettle();
    expect(find.byType(AnalysisScreen), findsOneWidget);

    // no menu leading to the analysis settings, the board editor or a study
    expect(find.byIcon(Icons.menu), findsNothing);
    // the share button at the top stays
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);

    BottomBarButton threatButton() =>
        tester.widget<BottomBarButton>(find.widgetWithIcon(BottomBarButton, Icons.crisis_alert));
    expect(threatButton().label, 'Show threat');
    await tester.tap(find.byIcon(Icons.crisis_alert));
    await tester.pumpAndSettle();
    expect(threatButton().label, 'Stop showing threat');
    expect(threatButton().highlighted, isTrue);
    await tester.tap(find.byIcon(Icons.crisis_alert));
    await tester.pumpAndSettle();
    expect(threatButton().label, 'Show threat');
    expect(threatButton().highlighted, isFalse);

    // with the engine off, the threat cannot be shown
    await tester.tap(find.byType(EngineToggleButton));
    await tester.pumpAndSettle();
    expect(threatButton().onTap, isNull);
  });

  testWidgets('the Drill History lists the past Drills, opened or deleted', (tester) async {
    await openHome(
      tester,
      signedIn: true,
      defaultPreferences: {
        SessionPreferencesStorage.key(PrefCategory.drill.storageKey, fakeAuthUser): jsonEncode(
          const DrillConfig(nbPuzzles: 1).toJson(),
        ),
      },
    );
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    expect(find.text('Todavía no has terminado ningún Drill.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await _playOnePuzzleDrill(tester);
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Healthy mix'), findsOneWidget);
    expect(find.text('0 %'), findsOneWidget);
    expect(find.textContaining('Esperado'), findsNothing, reason: 'in the Drill Summary only');
    expect(find.text('1000'), findsOneWidget);
    expect(find.text('Poco fiable'), findsOneWidget);
    // in the day header and the Drill
    expect(find.text('−10'), findsNWidgets(2));
    expect(find.text('1490'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing, reason: 'a single Drill');

    await tester.tap(find.text('Healthy mix'));
    await tester.pumpAndSettle();
    expect(find.text('Resumen del Drill'), findsOneWidget);
    expect(_summaryValue('Fallos'), '1');
    await tester.pageBack();
    await tester.pumpAndSettle();

    // the chart, from 2 Drills
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _playOnePuzzleDrill(tester);
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    expect(find.text('Healthy mix'), findsNWidgets(2));
    expect(find.text('2 Drills · '), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('Últimos 2 Drills'), findsOneWidget);
    await tester.tap(find.text('Aciertos'));
    await tester.pumpAndSettle();
    expect(find.byType(BarChart), findsOneWidget);
    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();
    expect(find.text('Todos los Drills (2)'), findsOneWidget);

    for (var i = 0; i < 2; i++) {
      await tester.longPress(find.text('Healthy mix').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Healthy mix'), findsNothing);
    expect(find.text('Todavía no has terminado ningún Drill.'), findsOneWidget);
  });
}

/// Plays a Drill of 1 puzzle from the home screen, failed, and goes back home from its summary.
Future<void> _playOnePuzzleDrill(WidgetTester tester) async {
  await tester.tap(find.text('Empezar'));
  await tester.pumpAndSettle();
  await _failCurrentPuzzle(tester);
  await tester.tap(find.byIcon(CupertinoIcons.play_arrow_solid));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Volver'), 200.0);
  await tester.tap(find.text('Volver'));
  await tester.pumpAndSettle();
}

/// Fails the puzzle the Drill is on by viewing its solution, once it is offered.
Future<void> _failCurrentPuzzle(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.tap(find.byIcon(Icons.flag_outlined));
  // the solution is replayed and the next arrow blinks: no pumpAndSettle
  await tester.pump(const Duration(seconds: 1));
}

Finder _clock() => find.descendant(
  of: find.ancestor(of: find.byIcon(Icons.timer_outlined), matching: find.byType(Row)).first,
  matching: find.byType(Text),
);

/// The time shown by the clock of the Drill screen, in seconds.
int _clockSeconds(WidgetTester tester) {
  final [minutes, seconds] = tester.widget<Text>(_clock()).data!.split(':');
  return int.parse(minutes) * 60 + int.parse(seconds);
}

Color? _clockColor(WidgetTester tester) => tester.widget<Text>(_clock()).style?.color;

/// The value shown next to a label of the Drill Summary, with its arrow icon written as →.
String _summaryValue(String label) {
  final tile = find.ancestor(of: find.text(label), matching: find.byType(ListTile));
  final trailing = find.byWidget((tile.evaluate().single.widget as ListTile).trailing!);
  return find
      .descendant(
        of: trailing,
        matchRoot: true,
        matching: find.byWidgetPredicate(
          (widget) => widget is Text || (widget is Icon && widget.icon == Icons.arrow_forward),
        ),
      )
      .evaluate()
      .map(
        (element) => switch (element.widget) {
          Text(:final data) => data,
          _ => '→',
        },
      )
      .join(' ');
}

bool _isChipSelected(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label)).selected;

num _sliderValue(WidgetTester tester) =>
    tester.widget<NonLinearSlider>(find.byType(NonLinearSlider)).value;
