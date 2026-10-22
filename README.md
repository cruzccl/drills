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

- You choose the number of puzzles, a theme or opening, and a difficulty, and press start.
- Puzzles are fetched and solved through the Lichess puzzle API, so they count on your Lichess
  account exactly as in the official app.
- While a Drill runs, only the progress is shown; results, rating changes and performance are
  revealed in the summary at the end.
- A Drill can be ended early, as a partial Drill. One left unfinished can be resumed at any time,
  even after the app was closed. Each Lichess account signed in on the device has its own.
- Past Drills are kept on the device in a Drill History, one per account, grouped by day, under a
  chart of their performance, rating or success rate; each one can be reviewed again or deleted.

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
