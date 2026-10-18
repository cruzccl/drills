# Own OAuth client with puzzle scopes, everything but Drills hidden

The official app logs in as `lichess_mobile` with the `web:mobile` scope, but Lichess requires every request made with a `web:mobile` token to carry an HMAC signature from a secret that only the official build has (`OAuthSignedClient` in lila), so a fork cannot use it. We log in through a client id of our own with only `puzzle:read` and `puzzle:write`: these are enough to fetch puzzle batches and submit solutions, so Drill puzzles count on Lichess exactly as in the official app.

## Consequences

- Most features that need an account (playing, messages, profile, studies, preferences…) only accept `web:mobile` and stop working, so every screen other than Drills is hidden. Hidden, not deleted: deleting it would turn every rebase onto upstream into a conflict.
- The app must be built against `lichess.org` explicitly, since its default host is `lichess.dev`.

## Considered Options

- **Personal access token pasted into the app**: same scopes and simpler code, but the token would have to be generated, copied and renewed by hand.
- **Keeping the rest of the app visible**: it would be full of buttons that fail or show empty screens.
