import 'package:dartchess/dartchess.dart';
import 'package:lichess_mobile/src/model/analysis/analysis_controller.dart';
import 'package:lichess_mobile/src/model/common/node.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle.dart';
import 'package:lichess_mobile/src/network/http.dart';

/// How a Drill's puzzle is opened on the analysis board, as the official puzzle screen does: from
/// the position the player has to solve, with its solution, from the player's side.
AnalysisOptions drillPuzzleAnalysisOptions(Puzzle puzzle) {
  final root = Root.fromPgnMoves(puzzle.game.pgn);
  // The last move of the game is the opponent's move that sets up the puzzle.
  final initialPosition = root.nodeAt(root.mainlinePath).position;
  var position = initialPosition;
  final sanMoves = <String>[];
  for (final uci in puzzle.puzzle.solution) {
    final (next, san) = position.makeSan(Move.parse(uci)!);
    position = next;
    sanMoves.add(san);
  }
  return AnalysisOptions.pgn(
    id: puzzle.puzzle.id,
    orientation: initialPosition.turn,
    pgn:
        '[FEN "${initialPosition.fen}"][Site "${lichessUri('/training/${puzzle.puzzle.id}')}"]'
        '${sanMoves.join(' ')}',
    isComputerAnalysisAllowed: true,
    variant: .standard,
    initialMoveCursor: 0,
  );
}
