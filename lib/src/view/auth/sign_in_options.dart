import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/auth/auth_controller.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/view/auth/email_login_screen.dart';
import 'package:lichess_mobile/src/widgets/adaptive_action_sheet.dart';
import 'package:material_ui/material_ui.dart';

/// Whether the user may sign in with an email login code instead of the browser.
const _kOffersEmailLogin = false;

/// Lets the user pick how to sign in, then starts the chosen flow.
///
/// The OAuth browser flow is the default, but it is unreliable on some Android browsers and OEMs,
/// hence the email login code alternative.
///
/// Failures of the browser flow are reported through [signInMutation], so callers are expected to
/// already listen to it with `showSignInErrorSnackBar`.
///
/// Drills skips the choice and always starts the browser flow: the email login code gives a
/// `web:mobile` token, which needs a request signature that a fork cannot produce (see
/// docs/adr/0001-own-oauth-client-with-puzzle-scopes.md). The email option is kept, hidden.
Future<void> showSignInOptions(BuildContext context, WidgetRef ref) {
  if (!_kOffersEmailLogin) {
    signInMutation.run(ref, (tsx) async {
      await tsx.get(authControllerProvider.notifier).signIn();
    }).ignore();
    return Future.value();
  }

  final navigator = Navigator.of(context, rootNavigator: true);

  return showAdaptiveActionSheet<void>(
    context: context,
    actions: [
      BottomSheetAction(
        makeLabel: (context) => Text(context.l10n.mobileSignInWithBrowser),
        leading: const Icon(Icons.open_in_browser),
        onPressed: () {
          // The error is surfaced by the caller's [ref.listen] on [signInMutation]; ignore the
          // rethrown future so it does not become an unhandled exception.
          signInMutation.run(ref, (tsx) async {
            await tsx.get(authControllerProvider.notifier).signIn();
          }).ignore();
        },
      ),
      BottomSheetAction(
        makeLabel: (context) => Text(context.l10n.mobileSignInWithEmail),
        leading: const Icon(Icons.mail_outline),
        onPressed: () {
          navigator.push(EmailLoginScreen.buildRoute());
        },
      ),
    ],
  );
}
