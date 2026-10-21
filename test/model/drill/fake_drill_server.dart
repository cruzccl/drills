import 'dart:convert';

import 'package:dartchess/dartchess.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_preferences.dart';

/// A fake Lichess puzzle server for Drill tests.
///
/// Every batch request, whatever its angle, is answered with new puzzles, so that a Drill never
/// runs out of them. All the puzzles are the same position under distinct ids: black to play,
/// solved by [solution] (the player plays the 1st and 3rd moves). The solutions posted are
/// recorded in [solutions], and each rated one moves the player's rating by [ratingDiff] (up when
/// won, down when lost). The openings offered are [openings]. While [isOffline], every request
/// fails; while [isSolveLimited], posting solutions does. Signing out succeeds.
class FakeDrillServer() {
  /// The solution of every puzzle served.
  static const solution = ['g4h4', 'h8h4', 'b4h4'];

  /// The player's moves of [solution].
  static final playerMoves = [Move.parse(solution[0])!, Move.parse(solution[2])!];

  /// The puzzle rating of every puzzle served, unless [puzzleRatingOf] says otherwise.
  static const puzzleRating = 1500;

  /// The player's puzzle rating before any solution is posted.
  static const initialRating = 1500;

  /// How much a rated solution moves the player's rating.
  static const ratingDiff = 10;

  /// The rating of the puzzle served at an index, from 0.
  int Function(int index) puzzleRatingOf = (_) => puzzleRating;

  /// The themes of the puzzle served at an index, from 0.
  List<String> Function(int index) puzzleThemesOf = (_) => const ['endgame', 'short', 'fork'];

  /// Whether every request fails, as without a connection.
  bool isOffline = false;

  /// Whether posting solutions is answered with 429 Too Many Requests, as when the player solved
  /// too many puzzles lately.
  bool isSolveLimited = false;

  /// The number of requests posting solutions, rate limited ones included.
  int nbSolveRequests = 0;

  /// The player's puzzle rating.
  int rating = initialRating;

  /// The solutions posted to the server, in order.
  final List<({String id, bool win, bool rated})> solutions = [];

  /// The number of puzzles served so far.
  int nbServed = 0;

  /// The number of puzzles the server has to serve, as for a rare theme or opening.
  int nbAvailable = 1 << 30;

  /// The difficulty asked by each batch request fetching puzzles, in order.
  ///
  /// Requests for no puzzles, with which the player's rating is read, are left out.
  final List<String?> difficulties = [];

  /// The angle (theme or opening key) of each batch request fetching puzzles, in order.
  final List<String> angles = [];

  /// The openings of `/training/openings`: a family with one variation.
  static const openings = {
    'openings': [
      {
        'family': {'key': 'Sicilian_Defense', 'name': 'Sicilian Defense', 'count': 300},
        'openings': [
          {'key': 'Sicilian_Defense_Najdorf_Variation', 'name': 'Najdorf Variation', 'count': 40},
        ],
      },
    ],
  };

  late final MockClient client = MockClient((request) async {
    if (isOffline) throw http.ClientException('offline', request.url);
    if (request.url.path == '/api/token' && request.method == 'DELETE') {
      // signing out
      return http.Response('{"ok": true}', 200);
    }
    if (request.url.path == '/training/openings') {
      return http.Response(jsonEncode(openings), 200);
    }
    final segments = request.url.pathSegments;
    if (segments.length != 4 || segments.take(3).join('/') != 'api/puzzle/batch') {
      return http.Response('', 404);
    }
    final rounds = <Map<String, dynamic>>[];
    if (request.method == 'POST') {
      nbSolveRequests++;
      // with its request, by which the client tells it from the 429s it retries
      if (isSolveLimited) return http.Response('', 429, request: request);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      for (final s in (body['solutions'] as List<dynamic>).cast<Map<String, dynamic>>()) {
        final solution = (id: s['id'] as String, win: s['win'] as bool, rated: s['rated'] as bool);
        solutions.add(solution);
        final diff = solution.rated ? (solution.win ? ratingDiff : -ratingDiff) : 0;
        rating += diff;
        rounds.add({'id': solution.id, 'win': solution.win, 'ratingDiff': diff});
      }
    }
    // As the real server, at most 50 puzzles per request.
    final nb = int.parse(request.url.queryParameters['nb'] ?? '0')
        .clamp(0, kServerPuzzleBatchCap)
        .clamp(0, nbAvailable - nbServed);
    if (nb > 0) {
      angles.add(segments.last);
      difficulties.add(request.url.queryParameters['difficulty']);
    }
    final puzzles = [
      for (var i = 0; i < nb; i++)
        _puzzleJson(
          'drill$nbServed',
          rating: puzzleRatingOf(nbServed),
          themes: puzzleThemesOf(nbServed++),
        ),
    ];
    return http.Response(
      jsonEncode({
        'puzzles': puzzles,
        'glicko': {'rating': rating.toDouble(), 'deviation': 80.0},
        if (request.method == 'POST') 'rounds': rounds,
      }),
      200,
    );
  });
}

Map<String, dynamic> _puzzleJson(
  String id, {
  required int rating,
  required List<String> themes,
}) => {
  'game': {
    'id': 'w32JTzEf',
    'perf': {'key': 'blitz', 'name': 'Blitz'},
    'rated': true,
    'players': [
      {'name': 'Li', 'rating': 1500, 'color': 'white'},
      {'name': 'Gabriela', 'rating': 1500, 'color': 'black'},
    ],
    'pgn':
        'e4 e5 Nf3 Nc6 Bb5 a6 Ba4 b5 Bb3 Nf6 c3 Nxe4 d4 exd4 cxd4 Qe7 O-O Qd8 Bd5 Nf6 Bb3 Bd6 '
        'Nc3 O-O Bg5 h6 Bh4 g5 Nxg5 hxg5 Bxg5 Kg7 Ne4 Be7 Bxf6+ Bxf6 Qg4+ Kh8 Qh5+ Kg8 Qg6+ Kh8 '
        'Qxf6+ Qxf6 Nxf6 Nxd4 Rfd1 Ne2+ Kh1 d6 Rd5 Kg7 Nh5+ Kh6 Rad1 Be6 R5d2 Bxb3 axb3 Kxh5 '
        'Rxe2 Rfe8 Red2 Re5 h3 Rae8 Kh2 Re2 Rd5+ Kg6 f4 Rxb2 R1d3 Ree2 Rg3+ Kf6 h4 Re4 Rg4 Rxb3 '
        'h5 Rbb4 h6 Rxf4 h7 Rxg4 h8=Q+ Ke7 Rd3',
    'clock': '3+0',
  },
  'puzzle': {
    'id': id,
    'rating': rating,
    'plays': 100,
    'initialPly': 88,
    'solution': FakeDrillServer.solution,
    'themes': themes,
  },
};
