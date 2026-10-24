# Puzzle Drills

A personal fork of Lichess Mobile whose home screen is a bounded tactics training mode. Puzzles solved here count on Lichess exactly as in the official app.

## Language

**Drill**:
A bounded series of a chosen number of puzzles, rated when signed in, configured when it starts, that ends with a Drill Summary.
A Drill played signed out counts on no Lichess account (its puzzles are unrated and nothing is sent to Lichess) and is not kept in any Drill History.
_Avoid_: Session, training, puzzle set

**Partial Drill**:
A Drill that ended before its last puzzle, because the player ended it or started another one before finishing it.
_Avoid_: Abandoned drill, cancelled drill

**Drill Summary**:
The report of a Drill's results shown when it ends.
_Avoid_: Recap, results screen

**Drill History**:
The list of past Drills and their Drill Summaries, one per Lichess account. Lichess doesn't know it: it is kept on the device, backed up with the app's data (Android Auto Backup), and exported to a file and imported back to change phones.

**Drill Performance**:
The rating level a Drill was played at, from the average puzzle rating and the share of puzzles solved, as Lichess computes puzzle performance. Unreliable below 6 puzzles.
_Avoid_: Rating, score

**Hint**:
The from-square of the current solution move, shown in a Drill as the step before giving up: the first hint of a puzzle fails it, on Lichess too (see ADR 0002).
_Avoid_: Clue, help

**Warm-up**:
A Puzzle Storm run started from the home screen before a Drill, exactly as in the official app; it is not part of the Drill and leaves no trace in its Drill Summary.
_Avoid_: Drill

**Puzzle Session**:
The official app's rolling window of recent puzzle attempts, with no defined start or end; distinct from a Drill.
_Avoid_: Drill
