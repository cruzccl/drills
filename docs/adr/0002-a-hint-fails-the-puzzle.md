# A hint fails the puzzle

In the official app, a hint only makes the puzzle unrated: solving it afterwards is sent as `{win: true, rated: false}`, which Lichess still counts as solved (a round is created, the puzzle is burned, the activity and the puzzle dashboard count it as a success). In a Drill, asking for a hint is the step before giving up, so the first hint of a puzzle fails it and sends `{win: false, rated: true}`, exactly what viewing the solution on the website sends. The rule is Drills' own, but every result sent is one the official clients send too.

## Consequences

- The hint and view-solution buttons are one button, **Hint** until a hint is shown for the current move, then **Give up**. A hint can no longer be hidden.
- Later hints of a puzzle already failed, by a hint or a wrong move, are only shown, never sent.
- `PuzzleController` (upstream) gets an additional method, `showHintAsFailure()`, rather than a change to `toggleHint()`, to keep rebases free of conflicts. It doesn't set `hintShown`, which would make the failure unrated.
- A Drill's success rate and performance count a puzzle solved after a hint as a failure; Drills kept from before this rule keep their unrated wins.

## Considered Options

- **Keeping the official rule**: a puzzle solved after a hint would count as solved on the Lichess puzzle dashboard, overstating what the player solved alone.
