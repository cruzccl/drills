/// Returns the bearer token as is.
///
/// Upstream signs it with the official app's secret, which Lichess requires for `web:mobile`
/// tokens only. Drills' tokens have the puzzle scopes, and must not carry that signature (see
/// docs/adr/0001-own-oauth-client-with-puzzle-scopes.md). The function is kept so that its callers
/// stay as upstream wrote them.
String signBearerToken(String token) => token;
