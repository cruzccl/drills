# Puzzle Drills

A personal fork of Lichess Mobile whose home screen is a bounded tactics training mode. Puzzles solved here count on Lichess exactly as in the official app.

## Language

**Drill**:
A bounded series of a chosen number of rated puzzles, configured when it starts, that ends with a Drill Summary.
_Avoid_: Session, training, puzzle set

**Partial Drill**:
A Drill that ended before its last puzzle, because the player ended it or started another one before finishing it.
_Avoid_: Abandoned drill, cancelled drill

**Drill Summary**:
The report of a Drill's results shown when it ends.
_Avoid_: Recap, results screen

**Drill History**:
The list of past Drills and their Drill Summaries, kept only on the device, one per Lichess account.

**Drill Performance**:
The rating level a Drill was played at, from the average puzzle rating and the share of puzzles solved, as Lichess computes puzzle performance. Unreliable below 6 puzzles.
_Avoid_: Rating, score

**Warm-up**:
A Puzzle Storm run started from the home screen before a Drill, exactly as in the official app; it is not part of the Drill and leaves no trace in its Drill Summary.
_Avoid_: Drill

**Puzzle Session**:
The official app's rolling window of recent puzzle attempts, with no defined start or end; distinct from a Drill.
_Avoid_: Drill
