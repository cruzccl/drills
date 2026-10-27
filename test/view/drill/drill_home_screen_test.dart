import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lichess_mobile/src/app.dart';
import 'package:lichess_mobile/src/network/http.dart';
import 'package:lichess_mobile/src/view/drill/drill_home_screen.dart';
import 'package:lichess_mobile/src/view/puzzle/storm_screen.dart';

import '../../model/auth/fake_auth_storage.dart';
import '../../network/fake_http_client_factory.dart';
import '../../test_provider_scope.dart';

void main() {
  testWidgets('opens Puzzle Storm to warm up, back to the Drill setup', (tester) async {
    final app = await makeTestProviderScope(
      tester,
      child: const Application(),
      authUser: fakeAuthUser,
      overrides: {
        httpClientFactoryProvider: httpClientFactoryProvider.overrideWith(
          (ref) => FakeHttpClientFactory(() => MockClient((_) async => http.Response('', 404))),
        ),
      },
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Warm up with Puzzle Storm'), 100);
    await tester.tap(find.text('Warm up with Puzzle Storm'));
    await tester.pumpAndSettle();
    expect(find.byType(StormScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(StormScreen), findsNothing);
    expect(find.byType(DrillHomeScreen), findsOneWidget);
  });
}
