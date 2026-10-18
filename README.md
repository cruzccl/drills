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

See [GLOSSARY.md](./GLOSSARY.md) for the terms used in this fork and [docs/adr](./docs/adr) for
the decisions behind it.

## License

Same as Lichess Mobile: GNU GPL v3 or later. See [COPYING.md](./COPYING.md) and
[LICENSE](./LICENSE).
