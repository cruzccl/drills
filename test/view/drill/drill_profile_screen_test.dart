import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lichess_mobile/src/app.dart';
import 'package:lichess_mobile/src/network/http.dart';
import 'package:lichess_mobile/src/view/drill/drill_home_screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_profile_screen.dart';
import 'package:lichess_mobile/src/view/puzzle/dashboard_screen.dart';
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

  /// The number of days asked for each Puzzle Storm dashboard.
  final stormDays = <String?>[];

  setUp(() {
    requests.clear();
    stormDays.clear();
  });

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
              if (request.url.path == '/api/storm/dashboard/testuser') {
                stormDays.add(request.url.queryParameters['days']);
              }
              return switch (request.url.path) {
                '/api/user/testuser' => http.Response(_userResponse, 200),
                '/api/user/testuser/rating-history' => http.Response(_ratingHistoryResponse, 200),
                '/api/user/testuser/activity' => http.Response(_activityResponse, 200),
                '/api/puzzle/dashboard/30' => http.Response(_dashboardResponse, 200),
                // Slow, to see the dashboard of the other days loading.
                '/api/puzzle/dashboard/7' => await Future.delayed(
                  const Duration(milliseconds: 500),
                  () => http.Response(_dashboardResponse, 200),
                ),
                '/api/storm/dashboard/testuser' => http.Response(_stormResponse(), 200),
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

    expect(find.text('Puzzles'), findsOneWidget);
    expect(find.text('2128'), findsWidgets);
    expect(find.text('10,336 played'), findsOneWidget);
    expect(find.text('highscore · 29 runs'), findsOneWidget);
    expect(find.text('2041'), findsNothing, reason: 'no blitz rating');

    // The details are behind the ratings, and only load once opened.
    expect(find.text('Puzzle rating'), findsNothing);
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
    await tester.tap(find.text('Puzzles'));
    await tester.pumpAndSettle();

    expect(find.text('Puzzle rating'), findsOneWidget);
    expect(find.text('Highest'), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(PuzzleChart), 200, scrollable: topScrollable);
    expect(find.textContaining('to replay'), findsNothing);
    await tester.scrollUntilVisible(find.text('Improvement areas'), 200, scrollable: topScrollable);
    await tester.scrollUntilVisible(find.text('Strengths'), 200, scrollable: topScrollable);
    expect(find.text('Fork'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Puzzle rating'), -200, scrollable: topScrollable);
    // A section reloaded on the way back would change height under the player's finger.
    expect(requests['/api/puzzle/dashboard/30'], 1);
    expect(requests['/api/user/testuser/rating-history'], 1);
  });

  testWidgets('the puzzle dashboard of other days loads without moving the screen', (tester) async {
    await openProfile(tester);
    await tester.tap(find.text('Puzzles'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(PuzzleChart), 200, scrollable: topScrollable);
    final offset = tester.state<ScrollableState>(topScrollable).position.pixels;

    ProviderScope.containerOf(tester.element(find.byType(PuzzleChart)))
            .read(daysProvider.notifier)
            .state =
        Days.week;
    await tester.pump();

    // The dashboard of the last 30 days stays while the one of the last week loads: the screen
    // doesn't go back to its top. It may only move by the line its narrower days selector frees.
    expect(find.byType(PuzzleChart), findsOneWidget);
    expect(tester.state<ScrollableState>(topScrollable).position.pixels, closeTo(offset, 30));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(requests['/api/puzzle/dashboard/7'], 1);
    expect(find.byType(PuzzleChart), findsOneWidget);
    expect(tester.state<ScrollableState>(topScrollable).position.pixels, closeTo(offset, 30));
  });

  testWidgets('a theme of the puzzle dashboard sets up the Drill', (tester) async {
    await openProfile(tester);
    await tester.tap(find.text('Puzzles'));
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
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.textContaining('+3 over the previous day', findRichText: true), findsOneWidget);
    expect(find.text('Best score of each day played · 8 days'), findsOneWidget);
    // Every day of the last month, not only the last week.
    await tester.scrollUntilVisible(find.text('1150'), 200, scrollable: topScrollable);
    expect(find.text('1306'), findsOneWidget);
  });

  testWidgets('the Puzzle Storm table shows only the days of the period chosen', (tester) async {
    await openProfile(tester);
    await tester.tap(find.text('Puzzle Storm'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('1150'), 200, scrollable: topScrollable);

    await tester.scrollUntilVisible(find.text('1W'), -200, scrollable: topScrollable);
    await tester.tap(find.text('1W'));
    await tester.pumpAndSettle();
    expect(stormDays, ['30', '7']);
    // The day played 9 days ago is out of the last week, though Lichess gives it.
    expect(find.text('1160'), findsOneWidget);
    expect(find.text('1150'), findsNothing);
  });

  testWidgets('the Puzzle Storm chart loads the period chosen without moving the screen', (
    tester,
  ) async {
    await openProfile(tester);
    await tester.tap(find.text('Puzzle Storm'));
    await tester.pumpAndSettle();
    expect(stormDays, ['30']);

    await tester.tap(find.text('3M'));
    await tester.pump();
    // The last 30 days stay while the last 90 load.
    expect(find.byType(BarChart), findsOneWidget);
    await tester.pumpAndSettle();
    expect(stormDays, ['30', '90']);
    expect(find.byType(BarChart), findsOneWidget);
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
{"days":30,"global":{"nb":100,"firstWins":60,"replayWins":0,"puzzleRatingAvg":1700,"performance":1700},"themes":{"mateIn3":{"theme":"Mate in 3","results":{"nb":20,"firstWins":8,"replayWins":0,"puzzleRatingAvg":1700,"performance":1500}},"fork":{"theme":"Fork","results":{"nb":30,"firstWins":27,"replayWins":0,"puzzleRatingAvg":1700,"performance":1900}},"pin":{"theme":"Pin","results":{"nb":10,"firstWins":6,"replayWins":0,"puzzleRatingAvg":1700,"performance":1650}}}}
''';

/// The Puzzle Storm dashboard, with days played relative to today so that they fall within the
/// periods of the chart.
String _stormResponse() {
  final today = DateTime.now();
  String day(int daysAgo) {
    final date = today.subtract(Duration(days: daysAgo));
    return '${date.year}/${date.month}/${date.day}';
  }

  return jsonEncode({
    'high': {'day': 15, 'week': 15, 'month': 15, 'allTime': 24},
    'days': [
      for (final (daysAgo, score, highest, runs) in [
        (0, 15, 1306, 1),
        (1, 12, 1210, 2),
        (2, 11, 1200, 1),
        (3, 10, 1190, 1),
        (4, 9, 1180, 1),
        (5, 8, 1170, 1),
        (6, 7, 1160, 1),
        (9, 6, 1150, 1),
      ])
        {
          '_id': day(daysAgo),
          'score': score,
          'moves': 30,
          'errors': 4,
          'combo': 10,
          'time': 150,
          'highest': highest,
          'runs': runs,
        },
    ],
  });
}
