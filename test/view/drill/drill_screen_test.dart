import 'package:chessground/chessground.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lichess_mobile/src/app.dart';
import 'package:lichess_mobile/src/network/http.dart';
import 'package:lichess_mobile/src/view/drill/drill_screen.dart';
import 'package:lichess_mobile/src/view/puzzle/puzzle_session_widget.dart';
import 'package:material_ui/material_ui.dart';

import '../../model/auth/fake_auth_storage.dart';
import '../../model/drill/fake_drill_server.dart';
import '../../network/fake_http_client_factory.dart';
import '../../test_helpers.dart';
import '../../test_provider_scope.dart';

void main() {
  late FakeDrillServer server;

  setUp(() => server = FakeDrillServer());

  Future<void> openHome(WidgetTester tester, {required bool signedIn}) async {
    final app = await makeTestProviderScope(
      tester,
      child: const Application(),
      authUser: signedIn ? fakeAuthUser : null,
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
}
