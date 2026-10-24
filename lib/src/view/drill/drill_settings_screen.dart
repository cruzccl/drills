import 'package:app_settings/app_settings.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/l10n/l10n.dart';
import 'package:lichess_mobile/src/model/auth/auth_controller.dart';
import 'package:lichess_mobile/src/model/common/preloaded_data.dart';
import 'package:lichess_mobile/src/model/drill/drill_preferences.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_preferences.dart';
import 'package:lichess_mobile/src/model/settings/board_preferences.dart';
import 'package:lichess_mobile/src/model/settings/general_preferences.dart';
import 'package:lichess_mobile/src/network/connectivity.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/view/auth/sign_in_error.dart';
import 'package:lichess_mobile/src/view/auth/sign_in_options.dart';
import 'package:lichess_mobile/src/view/drill/drill_strings.dart';
import 'package:lichess_mobile/src/view/settings/sound_settings_screen.dart';
import 'package:lichess_mobile/src/view/settings/theme_settings_screen.dart';
import 'package:lichess_mobile/src/widgets/adaptive_action_sheet.dart';
import 'package:lichess_mobile/src/widgets/adaptive_choice_picker.dart';
import 'package:lichess_mobile/src/widgets/feedback.dart';
import 'package:lichess_mobile/src/widgets/list.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';
import 'package:lichess_mobile/src/widgets/settings.dart';
import 'package:material_ui/material_ui.dart';

/// The settings of Drills: only those that affect Drills, out of the upstream [SettingsScreen].
///
/// The board and pieces are chosen in the theme settings.
class const DrillSettingsScreen({super.key}) extends ConsumerWidget {
  static Route<dynamic> buildRoute() {
    return buildScreenRoute(screen: const DrillSettingsScreen());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isDeviceOnlineProvider);
    final generalPrefs = ref.watch(generalPreferencesProvider);
    final puzzlePrefs = ref.watch(puzzlePreferencesProvider);
    final showClock = ref.watch(drillPreferencesProvider.select((p) => p.showClock));
    final hapticFeedback = ref.watch(boardPreferencesProvider.select((p) => p.hapticFeedback));
    final packageInfo = ref.read(preloadedDataProvider).requireValue.packageInfo;
    final authUser = ref.watch(authControllerProvider);
    final signInState = ref.watch(signInMutation);
    final signOutState = ref.watch(signOutMutation);

    ref.listen(signInMutation, (_, next) => showSignInErrorSnackBar(context, next));

    final chevron = Theme.of(context).platform == .iOS ? const CupertinoListTileChevron() : null;

    return PlatformScaffold(
      appBar: PlatformAppBar(title: Text(context.l10n.settingsSettings), largeTitle: true),
      body: ListView(
        children: [
          ListSection(
            header: const SettingsSectionTitle(DrillStrings.settingsAccount),
            hasLeading: true,
            children: [
              if (authUser != null)
                switch (signOutState) {
                  MutationPending() => const ListTile(
                    leading: Icon(Icons.logout_outlined),
                    enabled: false,
                    title: Center(child: ButtonLoadingIndicator()),
                  ),
                  _ => ListTile(
                    leading: const Icon(Icons.logout_outlined),
                    title: Text(context.l10n.logOut),
                    subtitle: Text(authUser.user.name),
                    enabled: isOnline,
                    onTap: () => _showSignOutConfirmDialog(context, ref),
                  ),
                }
              else
                ListTile(
                  leading: const Icon(Icons.login_outlined),
                  title: Text(context.l10n.signIn),
                  enabled: isOnline && signInState is! MutationPending,
                  onTap: () => showSignInOptions(context, ref),
                ),
            ],
          ),
          ListSection(
            header: const SettingsSectionTitle(DrillStrings.settingsDrills),
            hasLeading: false,
            children: [
              SwitchSettingTile(
                title: Text(context.l10n.puzzleJumpToNextPuzzleImmediately),
                value: puzzlePrefs.autoNext,
                onChanged: (value) {
                  ref.read(puzzlePreferencesProvider.notifier).setAutoNext(value);
                },
              ),
              SwitchSettingTile(
                title: const Text(DrillStrings.showClock),
                value: showClock,
                onChanged: (value) {
                  ref.read(drillPreferencesProvider.notifier).setShowClock(value);
                },
              ),
            ],
          ),
          ListSection(
            header: const SettingsSectionTitle(DrillStrings.settingsAppearance),
            hasLeading: true,
            children: [
              SettingsListTile(
                icon: const Icon(Icons.music_note_outlined),
                settingsLabel: Text(context.l10n.sound),
                settingsValue:
                    '${soundThemeL10n(context, generalPrefs.soundTheme)} (${volumeLabel(generalPrefs.masterVolume)})',
                onTap: () {
                  Navigator.of(context).push(SoundSettingsScreen.buildRoute());
                },
              ),
              SwitchSettingTile(
                leading: const Icon(Icons.vibration_outlined),
                title: Text(context.l10n.mobileSettingsTouchFeedback),
                value: hapticFeedback,
                onChanged: (value) {
                  ref.read(boardPreferencesProvider.notifier).toggleHapticFeedback();
                },
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: Text(context.l10n.mobileTheme),
                trailing: chevron,
                onTap: () {
                  Navigator.of(context).push(ThemeSettingsScreen.buildRoute());
                },
              ),
              SettingsListTile(
                icon: const Icon(Icons.language_outlined),
                settingsLabel: Text(context.l10n.language),
                settingsValue: localeToLocalizedName(
                  generalPrefs.locale ?? Localizations.localeOf(context),
                ),
                onTap: () {
                  if (Theme.of(context).platform == .android) {
                    showChoicePicker<Locale>(
                      context,
                      choices: localesSortedByLocalizedName(AppLocalizations.supportedLocales),
                      selectedItem: generalPrefs.locale ?? Localizations.localeOf(context),
                      labelBuilder: (t) => Text(localeToLocalizedName(t)),
                      onSelectedItemChanged: (Locale? locale) =>
                          ref.read(generalPreferencesProvider.notifier).setLocale(locale),
                    );
                  } else {
                    AppSettings.openAppSettings(type: .appLocale);
                  }
                },
              ),
            ],
          ),
          Padding(
            padding: Styles.bodySectionPadding,
            child: Text(
              '${DrillStrings.about}\n\nv${packageInfo.version}',
              style: TextTheme.of(context).bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSignOutConfirmDialog(BuildContext context, WidgetRef ref) {
    Future<void> signOut() => signOutMutation.run(ref, (tsx) async {
      await tsx.get(authControllerProvider.notifier).signOut();
    });

    if (Theme.of(context).platform == .iOS) {
      return showCupertinoActionSheet(
        context: context,
        actions: [
          BottomSheetAction(
            makeLabel: (context) => Text(context.l10n.logOut),
            isDestructiveAction: true,
            onPressed: signOut,
          ),
        ],
      );
    }
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.logOut),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                signOut();
              },
              child: Text(context.l10n.mobileOkButton),
            ),
          ],
        );
      },
    );
  }
}
