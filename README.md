# Drills

A personal tactics trainer built on top of [Lichess Mobile](https://github.com/lichess-org/mobile).

This is an unofficial fork for my own use. It is not affiliated with or endorsed by
Lichess, and no builds are distributed. For the official app, see https://lichess.org/mobile.

Huge thanks to Lichess and all its contributors for making such a wonderful,
free and open-source project. Please consider supporting it at https://lichess.org/patron.

The Drill feature in this fork was developed with the help of AI tools.

## What it does

The app opens straight into a **Drill**: a bounded series of rated Lichess puzzles that ends with a
summary of the results.

- The home screen sets up the next Drill as the last one started: its number of puzzles, theme or
  opening, and difficulty are each changed on their own sheet or screen, the changes outlined and
  undone in one tap. The themes most failed in the last 10 Drills are offered first.
- Puzzles are fetched and solved through the Lichess puzzle API, so they count on your Lichess
  account exactly as in the official app.
- Signed out, Drills can still be played anonymously: their puzzles are unrated, nothing is sent
  to Lichess, and they are not kept in any Drill History.
- While a Drill runs, only the progress is shown; results, rating changes and performance are
  revealed in the summary at the end, with the time spent on each puzzle and the weakest themes,
  each of which sets up the next Drill. A setting can also show how long you have been on the
  puzzle in progress, timed only while the app is shown.
- A Drill can be ended early, as a partial Drill. One left unfinished can be resumed at any time,
  even after the app was closed. Each Lichess account signed in on the device has its own.
- Puzzle Storm, as in the official app, is one tap away on the home screen, to warm up before a
  Drill. It counts neither on the puzzle rating nor in the Drill.
- Past Drills are kept on the device in a Drill History, one per account, grouped by day; each
  Drill can be reviewed again or deleted. The home screen lists the last 3, and shows your streak
  of days in a row with a Drill over this week.
- The streak opens your progress: your current and best streaks, a calendar of the days played,
  and charts of your performance and success rate over the last week, month, 3 months, year or
  all of them, by day played (by week over longer ranges), with their averages.
- Your Lichess profile, from your avatar on the home screen, shows only puzzles and Puzzle Storm:
  the two ratings and the daily activity. The puzzle rating opens the puzzle rating history and the
  puzzle dashboard, whose themes set up the next Drill; the Puzzle Storm one opens the Storm high
  scores and the best run of every day, as in the official app, over the last week, month, three
  months or year, with a chart of them.

See [GLOSSARY.md](./GLOSSARY.md) for the terms used in this fork and [docs/adr](./docs/adr) for
the decisions behind it.

## Building

Only Android is targeted. The app is `io.github.cruzccl.drills`, so it installs alongside the
official app, talks to lichess.org and has Firebase disabled.

- Flutter through [fvm](https://fvm.app) (`fvm install`, the version required is pinned in
  `pubspec.yaml`), the Android command-line tools and a JDK 21.
- `fvm flutter pub get && fvm dart run build_runner build`
- Release builds are signed with a personal keystore kept outside the repository, configured in
  the git-ignored `android/key.properties`:

  ```properties
  storeFile=/absolute/path/to/drills-release.jks
  storePassword=...
  keyAlias=drills
  keyPassword=...
  ```

- `fvm flutter build apk --release`, then
  `adb install build/app/outputs/flutter-apk/app-release.apk`

Losing the keystore, or changing the package id, means reinstalling the app and losing the Drill
History.

## License

Same as Lichess Mobile: GNU GPL v3 or later. See [COPYING.md](./COPYING.md) and
[LICENSE](./LICENSE).

The app icon is ["Archery target"](https://game-icons.net/1x1/lorc/archery-target.html) by
[Lorc](https://lorcblog.blogspot.com), from [game-icons.net](https://game-icons.net), licensed
under [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/).
