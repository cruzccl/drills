import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderOrFamily;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lichess_mobile/src/app.dart';
import 'package:lichess_mobile/src/model/auth/auth_repository.dart';
import 'package:lichess_mobile/src/model/drill/drill_preferences.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_preferences.dart';
import 'package:lichess_mobile/src/model/settings/board_preferences.dart';
import 'package:lichess_mobile/src/network/http.dart';
import 'package:lichess_mobile/src/view/drill/drill_settings_screen.dart';
import 'package:lichess_mobile/src/widgets/platform_switch.dart';
import 'package:material_ui/material_ui.dart';

import '../../model/auth/auth_repository_test.dart';
import '../../model/auth/fake_auth_storage.dart';
import '../../network/fake_http_client_factory.dart';
import '../../test_provider_scope.dart';

void main() {
  final requests = <http.Request>[];

  setUp(requests.clear);

  final httpOverride = httpClientFactoryProvider.overrideWith(
    (ref) => FakeHttpClientFactory(
      () => MockClient((request) async {
        requests.add(request);
        if (request.method == 'DELETE' && request.url.path == '/api/token') {
          return http.Response('', 204);
        }
        return http.Response('', 404);
      }),
    ),
  );

  Future<void> openSettings(
    WidgetTester tester, {
    bool signedIn = true,
    Map<ProviderOrFamily, Override>? overrides,
  }) async {
    final app = await makeTestProviderScope(
      tester,
      child: const Application(),
      authUser: signedIn ? fakeAuthUser : null,
      overrides: {httpClientFactoryProvider: httpOverride, ...?overrides},
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(DrillSettingsScreen), findsOneWidget);
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(DrillSettingsScreen)));

  Future<void> scrollTo(WidgetTester tester, Finder finder) => tester.scrollUntilVisible(
    finder,
    100,
    scrollable: find.descendant(
      of: find.byType(DrillSettingsScreen),
      matching: find.byType(Scrollable),
    ),
  );

  Future<void> toggle(WidgetTester tester, String label) async {
    await scrollTo(tester, find.text(label));
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, label),
        matching: find.byType(PlatformSwitch),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('offers only the settings that affect Drills', (tester) async {
    await openSettings(tester);

    for (final label in [
      'Sign out',
      'Jump to next puzzle immediately',
      'Show clock',
      'Sound',
      'Touch feedback',
      'Theme',
      'Language',
    ]) {
      await scrollTo(tester, find.text(label));
      expect(find.text(label), findsOneWidget, reason: label);
    }

    for (final label in [
      'Account preferences',
      'Home widgets',
      'Board settings',
      'Chess engine',
      'Rate this app',
      'HTTP logs',
      'App Logs',
    ]) {
      expect(find.text(label, skipOffstage: false), findsNothing, reason: label);
    }
  });

  testWidgets('credits Lichess Mobile and thanks Lichess', (tester) async {
    await openSettings(tester);

    final about = find.textContaining('Lichess Mobile');
    await scrollTo(tester, about);
    expect(about, findsOneWidget);
    expect(find.textContaining('Thanks to Lichess'), findsOneWidget);
    expect(find.textContaining('Support Lichess'), findsOneWidget);
  });

  testWidgets('the puzzle, clock and touch feedback switches change the preferences', (
    tester,
  ) async {
    await openSettings(tester);
    final container = containerOf(tester);

    expect(container.read(puzzlePreferencesProvider).autoNext, false);
    await toggle(tester, 'Jump to next puzzle immediately');
    expect(container.read(puzzlePreferencesProvider).autoNext, true);

    expect(container.read(drillPreferencesProvider).showClock, false);
    await toggle(tester, 'Show clock');
    expect(container.read(drillPreferencesProvider).showClock, true);

    final hapticFeedback = container.read(boardPreferencesProvider).hapticFeedback;
    await toggle(tester, 'Touch feedback');
    expect(container.read(boardPreferencesProvider).hapticFeedback, !hapticFeedback);
  });

  testWidgets('signs out', (tester) async {
    await openSettings(tester);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(requests.where((r) => r.method == 'DELETE' && r.url.path == '/api/token'), hasLength(1));
    expect(find.text('Sign out'), findsNothing);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('signed out, signing in starts the browser flow', (tester) async {
    var nbAuthorizations = 0;
    await openSettings(
      tester,
      signedIn: false,
      overrides: {
        appAuthProvider: appAuthProvider.overrideWith(
          (ref) => FakeFlutterAppAuth((request) {
            nbAuthorizations++;
            return Future.error(userCancelled());
          }),
        ),
      },
    );

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(nbAuthorizations, 1);
  });
}
