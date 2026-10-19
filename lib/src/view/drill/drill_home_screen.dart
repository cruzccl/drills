import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/view/drill/drill_settings_screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_strings.dart';
import 'package:lichess_mobile/src/widgets/buttons.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';
import 'package:material_ui/material_ui.dart';

/// The screen the app opens on, where Drills are set up and started.
class const DrillHomeScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
          child: Text(
            DrillStrings.homeEmpty,
            textAlign: .center,
            style: TextTheme.of(context).bodyLarge,
          ),
        ),
      ),
    );
  }
}
