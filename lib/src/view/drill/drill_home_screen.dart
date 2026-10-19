import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/auth/auth_controller.dart';
import 'package:lichess_mobile/src/model/drill/drill_controller.dart';
import 'package:lichess_mobile/src/network/connectivity.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/view/auth/sign_in_error.dart';
import 'package:lichess_mobile/src/view/auth/sign_in_options.dart';
import 'package:lichess_mobile/src/view/drill/drill_screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_settings_screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_strings.dart';
import 'package:lichess_mobile/src/widgets/buttons.dart';
import 'package:lichess_mobile/src/widgets/feedback.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';
import 'package:lichess_mobile/src/widgets/platform_filled_button.dart';
import 'package:material_ui/material_ui.dart';

/// The Drill started from the home screen, until Drills can be configured.
const _drillConfig = DrillConfig(nbPuzzles: 5);

/// The screen the app opens on, where Drills are set up and started.
///
/// Signed out, it only offers to sign in, so that no puzzle is solved without counting on the
/// player's account.
class const DrillHomeScreen({super.key}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<DrillHomeScreen> createState() => _DrillHomeScreenState();
}

class _DrillHomeScreenState() extends ConsumerState<DrillHomeScreen> {
  bool _isStarting = false;

  Future<void> _startDrill() async {
    setState(() => _isStarting = true);
    final started = await ref.read(drillControllerProvider.notifier).start(_drillConfig);
    if (!mounted) return;
    setState(() => _isStarting = false);
    if (started) {
      Navigator.of(context).push(DrillScreen.buildRoute());
    } else {
      showSnackBar(context, DrillStrings.couldNotStartDrill, type: SnackBarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSignedIn = ref.watch(authControllerProvider) != null;
    final isOnline = ref.watch(isDeviceOnlineProvider);
    final signInState = ref.watch(signInMutation);

    ref.listen(signInMutation, (_, next) => showSignInErrorSnackBar(context, next));

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text(DrillStrings.appName),
        actions: [
          SemanticIconButton(
            icon: const Icon(Icons.settings_outlined),
            semanticsLabel: context.l10n.settingsSettings,
            onPressed: () => Navigator.of(context).push(DrillSettingsScreen.buildRoute()),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: Styles.bodyPadding,
          child: Column(
            mainAxisSize: .min,
            children: [
              Text(
                isSignedIn ? DrillStrings.homeDrillDescription : DrillStrings.homeSignInPrompt,
                textAlign: .center,
                style: TextTheme.of(context).bodyLarge,
              ),
              const SizedBox(height: 24.0),
              if (isSignedIn)
                PlatformFilledButton(
                  onPressed: _isStarting ? null : _startDrill,
                  child: _isStarting
                      ? const ButtonLoadingIndicator()
                      : const Text(DrillStrings.startDrill),
                )
              else
                PlatformFilledButton(
                  onPressed: isOnline && signInState is! MutationPending
                      ? () => showSignInOptions(context, ref)
                      : null,
                  child: Text(context.l10n.signIn),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
