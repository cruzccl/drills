import 'dart:convert';

import 'package:dartchess/dartchess.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A fake Lichess puzzle server for Drill tests.
///
/// Every batch request of the mix angle is answered with new puzzles, so that a Drill never runs
/// out of them. All the puzzles are the same position under distinct ids: black to play, solved
/// by [solution] (the player plays the 1st and 3rd moves). The solutions posted are recorded in
/// [solutions].
class FakeDrillServer() {
  /// The solution of every puzzle served.
  static const solution = ['g4h4', 'h8h4', 'b4h4'];

  /// The player's moves of [solution].
  static final playerMoves = [Move.parse(solution[0])!, Move.parse(solution[2])!];

  /// The puzzle rating of every puzzle served.
  static const puzzleRating = 1500;

  /// The solutions posted to the server, in order.
  final List<({String id, bool win, bool rated})> solutions = [];

  /// The number of puzzles served so far.
  int nbServed = 0;

  /// The difficulty asked by each batch request, in order.
  final List<String?> difficulties = [];

  late final MockClient client = MockClient((request) async {
    if (request.url.path != '/api/puzzle/batch/mix') {
      return http.Response('', 404);
    }
    difficulties.add(request.url.queryParameters['difficulty']);
    if (request.method == 'POST') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      for (final s in (body['solutions'] as List<dynamic>).cast<Map<String, dynamic>>()) {
        solutions.add((id: s['id'] as String, win: s['win'] as bool, rated: s['rated'] as bool));
      }
    }
    // The server sends at most 50 puzzles per request; a few are enough here.
    final nb = int.parse(request.url.queryParameters['nb'] ?? '0').clamp(0, 5);
    final puzzles = [for (var i = 0; i < nb; i++) _puzzleJson('drill${nbServed++}')];
    return http.Response(
      jsonEncode({
        'puzzles': puzzles,
        'glicko': {'rating': 1500.0, 'deviation': 80.0},
      }),
      200,
    );
  });
}

Map<String, dynamic> _puzzleJson(String id) => {
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
    'rating': FakeDrillServer.puzzleRating,
    'plays': 100,
    'initialPly': 88,
    'solution': FakeDrillServer.solution,
    'themes': ['endgame', 'short', 'fork'],
  },
};
