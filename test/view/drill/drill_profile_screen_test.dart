import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lichess_mobile/src/app.dart';
import 'package:lichess_mobile/src/network/http.dart';
import 'package:lichess_mobile/src/view/drill/drill_home_screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_profile_screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_strings.dart';
import 'package:lichess_mobile/src/widgets/user.dart';

import '../../model/auth/fake_auth_storage.dart';
import '../../network/fake_http_client_factory.dart';
import '../../test_provider_scope.dart';

void main() {
  // The Drill home stays below the profile, with its own list.
  final profileScrollable = find
      .descendant(of: find.byType(DrillProfileScreen), matching: find.byType(Scrollable))
      .first;

  // The screen on top, once the screens below it are offstage.
  final topScrollable = find.byType(Scrollable).first;

  /// The number of requests made for each path.
  final requests = <String, int>{};

  setUp(requests.clear);

  Future<void> openProfile(WidgetTester tester) async {
    final app = await makeTestProviderScope(
      tester,
      child: const Application(),
      authUser: fakeAuthUser,
      overrides: {
        httpClientFactoryProvider: httpClientFactoryProvider.overrideWith(
          (ref) => FakeHttpClientFactory(
            () => MockClient((request) async {
              requests.update(request.url.path, (nb) => nb + 1, ifAbsent: () => 1);
              return switch (request.url.path) {
                '/api/user/testuser' => http.Response(_userResponse, 200),
                '/api/user/testuser/rating-history' => http.Response(_ratingHistoryResponse, 200),
                '/api/user/testuser/activity' => http.Response(_activityResponse, 200),
                '/api/puzzle/dashboard/30' => http.Response(_dashboardResponse, 200),
                '/api/storm/dashboard/testuser' => http.Response(_stormResponse, 200),
                _ => http.Response('', 404),
              };
            }),
          ),
        ),
      },
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(UserAvatar));
    await tester.pumpAndSettle();
    expect(find.byType(DrillProfileScreen), findsOneWidget);
  }

  testWidgets('shows the profile filtered to puzzles and Puzzle Storm', (tester) async {
    await openProfile(tester);

    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('Vitoria-Gasteiz', findRichText: true), findsOneWidget);
    // No games: neither their number nor the time spent playing.
    expect(find.textContaining('605'), findsNothing);
    expect(find.textContaining('Time spent playing'), findsNothing);

    expect(find.text(DrillStrings.puzzles), findsOneWidget);
    expect(find.text('2128'), findsWidgets);
    expect(find.text('10,336 ${DrillStrings.played}'), findsOneWidget);
    expect(find.text('${DrillStrings.highScore} · 29 ${DrillStrings.runs}'), findsOneWidget);
    expect(find.text('2041'), findsNothing, reason: 'no blitz rating');

    // The details are behind the ratings, and only load once opened.
    expect(find.text(DrillStrings.puzzleRating), findsNothing);
    expect(find.text('Highscores'), findsNothing);
    expect(requests['/api/puzzle/dashboard/30'], isNull);
    expect(requests['/api/storm/dashboard/testuser'], isNull);

    await tester.scrollUntilVisible(find.text('Activity'), 200, scrollable: profileScrollable);
    await tester.scrollUntilVisible(
      find.textContaining('of Puzzle Storm'),
      200,
      scrollable: profileScrollable,
    );
    expect(find.textContaining('Solved 4'), findsOneWidget);
    expect(find.textContaining('Played 3'), findsNothing, reason: 'no games in the activity');
  });

  testWidgets('the puzzle rating opens the rating history and the puzzle dashboard', (
    tester,
  ) async {
    await openProfile(tester);
    await tester.tap(find.text(DrillStrings.puzzles));
    await tester.pumpAndSettle();

    expect(find.text(DrillStrings.puzzleRating), findsOneWidget);
    expect(find.text(DrillStrings.highestRating), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Improvement areas'), 200, scrollable: topScrollable);
    await tester.scrollUntilVisible(find.text('Strengths'), 200, scrollable: topScrollable);
    expect(find.text('Fork'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text(DrillStrings.puzzleRating),
      -200,
      scrollable: topScrollable,
    );
    // A section reloaded on the way back would change height under the player's finger.
    expect(requests['/api/puzzle/dashboard/30'], 1);
    expect(requests['/api/user/testuser/rating-history'], 1);
  });

  testWidgets('a theme of the puzzle dashboard sets up the Drill', (tester) async {
    await openProfile(tester);
    await tester.tap(find.text(DrillStrings.puzzles));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Mate in 3').hitTestable(),
      topScrollable,
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mate in 3'));
    await tester.pumpAndSettle();

    expect(find.byType(DrillProfileScreen), findsNothing);
    expect(find.byType(DrillHomeScreen), findsOneWidget);
    expect(find.text('Mate in 3'), findsOneWidget);
  });

  testWidgets('the Puzzle Storm rating opens the high scores and the best run of every day', (
    tester,
  ) async {
    await openProfile(tester);
    await tester.tap(find.text('Puzzle Storm'));
    await tester.pumpAndSettle();

    expect(find.text('Highscores'), findsOneWidget);
    expect(find.text('All-time'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);
    expect(find.text('Best run of day'), findsOneWidget);
    // Every day Lichess gives, not only the last week.
    await tester.scrollUntilVisible(find.textContaining('Oct 14'), 200, scrollable: topScrollable);
    expect(find.text('1306'), findsOneWidget);
  });
}

const _userResponse = '''
{"id":"testuser","username":"testUser","flair":"smileys.alien","patron":true,"patronColor":7,"createdAt":1696195844969,"profile":{"flag":"ES-EU","location":"Vitoria-Gasteiz","bio":"ikasten","realName":"Test User"},"seenAt":1792763737157,"playTime":{"total":510560,"tv":0},"url":"https://lichess.org/@/testUser","count":{"all":605,"rated":519,"draw":44,"loss":265,"win":296,"bookmark":23,"playing":0,"import":237,"me":0},"perfs":{"blitz":{"games":300,"rating":2041,"rd":60,"prog":-17},"puzzle":{"games":10336,"rating":2128,"rd":77,"prog":9},"storm":{"runs":29,"score":24}}}
''';

const _ratingHistoryResponse = '''
[{"name":"Blitz","points":[[2025,0,1,2000],[2026,9,20,2041]]},{"name":"Puzzles","points":[[2025,0,1,1890],[2025,6,1,2237],[2026,9,23,2128]]}]
''';

const _activityResponse = '''
[{"interval":{"start":1792713600000,"end":1792800000000},"games":{"blitz":{"win":2,"loss":1,"draw":0,"rp":{"before":2050,"after":2041}}},"puzzles":{"score":{"win":2,"loss":2,"draw":0,"rp":{"before":2119,"after":2128}}},"storm":{"runs":1,"score":15}},{"interval":{"start":1792627200000,"end":1792713600000},"games":{"blitz":{"win":1,"loss":2,"draw":0,"rp":{"before":2060,"after":2050}}}}]
''';

const _dashboardResponse = '''
{"days":30,"global":{"nb":100,"firstWins":60,"replayWins":0,"puzzleRatingAvg":1700,"performance":1700},"themes":{"mateIn3":{"theme":"Mate in 3","results":{"nb":20,"firstWins":8,"replayWins":0,"puzzleRatingAvg":1700,"performance":1500}},"fork":{"theme":"Fork","results":{"nb":30,"firstWins":27,"replayWins":0,"puzzleRatingAvg":1700,"performance":1900}}}}
''';

const _stormResponse = '''
{"high":{"day":15,"week":15,"month":15,"allTime":24},"days":[{"_id":"2026/10/23","score":15,"moves":40,"errors":5,"combo":14,"time":147,"highest":1306,"runs":1},{"_id":"2026/10/22","score":12,"moves":30,"errors":4,"combo":10,"time":150,"highest":1210,"runs":2},{"_id":"2026/10/21","score":11,"moves":30,"errors":4,"combo":10,"time":150,"highest":1200,"runs":1},{"_id":"2026/10/20","score":10,"moves":30,"errors":4,"combo":10,"time":150,"highest":1190,"runs":1},{"_id":"2026/10/19","score":9,"moves":30,"errors":4,"combo":10,"time":150,"highest":1180,"runs":1},{"_id":"2026/10/18","score":8,"moves":30,"errors":4,"combo":10,"time":150,"highest":1170,"runs":1},{"_id":"2026/10/17","score":7,"moves":30,"errors":4,"combo":10,"time":150,"highest":1160,"runs":1},{"_id":"2026/10/14","score":6,"moves":30,"errors":4,"combo":10,"time":150,"highest":1150,"runs":1}]}
''';
