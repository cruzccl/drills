import 'dart:convert';

import 'package:chessground/chessground.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lichess_mobile/src/app.dart';
import 'package:lichess_mobile/src/model/drill/drill_controller.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_angle.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_difficulty.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_theme.dart';
import 'package:lichess_mobile/src/network/http.dart';
import 'package:lichess_mobile/src/view/drill/drill_screen.dart';
import 'package:lichess_mobile/src/view/puzzle/puzzle_session_widget.dart';
import 'package:lichess_mobile/src/widgets/non_linear_slider.dart';
import 'package:material_ui/material_ui.dart';

import '../../model/auth/fake_auth_storage.dart';
import '../../model/drill/fake_drill_server.dart';
import '../../network/fake_http_client_factory.dart';
import '../../test_helpers.dart';
import '../../test_provider_scope.dart';

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
    expect(find.text('Aciertos: 1'), findsOneWidget);
    expect(find.text('Fallos: 4'), findsOneWidget);
    expect(find.text('Porcentaje de aciertos: 20 %'), findsOneWidget);
    expect(server.solutions.map((s) => s.win), [true, false, false, false, false]);
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
        'preferences.drill': jsonEncode(
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
}

bool _isChipSelected(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label)).selected;

num _sliderValue(WidgetTester tester) =>
    tester.widget<NonLinearSlider>(find.byType(NonLinearSlider)).value;
