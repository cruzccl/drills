import 'package:flutter/services.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/auth/auth_controller.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/drill/drill_controller.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_difficulty.dart';
import 'package:lichess_mobile/src/model/settings/board_preferences.dart';
import 'package:lichess_mobile/src/model/user/user_repository_providers.dart';
import 'package:lichess_mobile/src/network/connectivity.dart';
import 'package:lichess_mobile/src/styles/lichess_icons.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/view/auth/sign_in_error.dart';
import 'package:lichess_mobile/src/view/auth/sign_in_options.dart';
import 'package:lichess_mobile/src/view/drill/drill_angle_screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_history_screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_profile_screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_settings_screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_strings.dart';
import 'package:lichess_mobile/src/view/puzzle/storm_screen.dart';
import 'package:lichess_mobile/src/widgets/adaptive_action_sheet.dart';
import 'package:lichess_mobile/src/widgets/adaptive_choice_picker.dart';
import 'package:lichess_mobile/src/widgets/buttons.dart';
import 'package:lichess_mobile/src/widgets/feedback.dart';
import 'package:lichess_mobile/src/widgets/filter.dart';
import 'package:lichess_mobile/src/widgets/list.dart';
import 'package:lichess_mobile/src/widgets/non_linear_slider.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';
import 'package:lichess_mobile/src/widgets/platform_choice_chip.dart';
import 'package:lichess_mobile/src/widgets/platform_filled_button.dart';
import 'package:lichess_mobile/src/widgets/settings.dart';
import 'package:lichess_mobile/src/widgets/user.dart';
import 'package:material_ui/material_ui.dart';

/// The numbers of puzzles offered to set up a Drill with one tap.
const _quickPickNbPuzzles = [5, 10, 12, 15, 20, 25];

/// Every number of puzzles a Drill can have, along the slider.
final _sliderNbPuzzles = [for (var nb = 1; nb <= kMaxDrillPuzzles; nb++) nb];

/// The screen the app opens on, where Drills are set up and started.
///
/// The configuration of the last Drill started is preselected. Signed out, it only offers to sign
/// in, so that no puzzle is solved without counting on the player's account.
class const DrillHomeScreen({super.key}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<DrillHomeScreen> createState() => _DrillHomeScreenState();
}

class _DrillHomeScreenState() extends ConsumerState<DrillHomeScreen> {
  bool _isStarting = false;
  late DrillConfig _config = ref.read(lastDrillConfigProvider);

  Future<void> _startDrill() async {
    setState(() => _isStarting = true);
    final started = await ref.read(drillControllerProvider.notifier).start(_config);
    if (!mounted) return;
    setState(() => _isStarting = false);
    if (started) {
      Navigator.of(context).push(DrillScreen.buildRoute());
    } else {
      showSnackBar(context, DrillStrings.couldNotStartDrill, type: SnackBarType.error);
    }
  }

  Future<void> _resumeDrill() async {
    setState(() => _isStarting = true);
    final resumed = await ref.read(drillControllerProvider.notifier).resume();
    if (!mounted) return;
    setState(() => _isStarting = false);
    if (resumed) {
      Navigator.of(context).push(DrillScreen.buildRoute());
    } else {
      showSnackBar(context, DrillStrings.couldNotStartDrill, type: SnackBarType.error);
    }
  }

  void _setNbPuzzles(int nbPuzzles) {
    if (nbPuzzles == _config.nbPuzzles) return;
    if (ref.read(boardPreferencesProvider).hapticFeedback) HapticFeedback.selectionClick();
    setState(() => _config = _config.copyWith(nbPuzzles: nbPuzzles));
  }

  Future<void> _chooseAngle() async {
    final angle = await Navigator.of(context).push(DrillAngleScreen.buildRoute(_config.angle));
    if (angle != null && mounted) {
      setState(() => _config = _config.copyWith(angle: angle));
    }
  }

  /// Opens the player's profile, whose dashboard themes set up the Drill.
  Future<void> _openProfile(UserId userId) async {
    final angle = await Navigator.of(context).push(DrillProfileScreen.buildRoute(userId));
    if (angle != null && mounted) {
      setState(() => _config = _config.copyWith(angle: angle));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authControllerProvider);
    final isSignedIn = authUser != null;
    final isOnline = ref.watch(isDeviceOnlineProvider);
    final signInState = ref.watch(signInMutation);
    final unfinishedDrill = ref.watch(unfinishedDrillProvider);

    ref.listen(signInMutation, (_, next) => showSignInErrorSnackBar(context, next));

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text(DrillStrings.appName),
        actions: [
          if (isSignedIn)
            SemanticIconButton(
              icon: const Icon(Icons.history),
              semanticsLabel: DrillStrings.history,
              onPressed: () => Navigator.of(context).push(DrillHistoryScreen.buildRoute()),
            ),
          SemanticIconButton(
            icon: const Icon(Icons.settings_outlined),
            semanticsLabel: context.l10n.settingsSettings,
            onPressed: () => Navigator.of(context).push(DrillSettingsScreen.buildRoute()),
          ),
          if (authUser != null)
            SemanticIconButton(
              // The profile's user has the flair, which the signed in user lacks.
              icon: UserAvatar(
                ref.watch(userProvider(authUser.user.id)).value?.lightUser ?? authUser.user,
                radius: 14,
              ),
              semanticsLabel: DrillStrings.profile,
              onPressed: () => _openProfile(authUser.user.id),
            ),
        ],
      ),
      body: isSignedIn
          // The body's own context: the padding of the screen's isn't the one inside the scaffold.
          ? Builder(
              builder: (context) => ListView(
                padding: Styles.bodyPadding.add(MediaQuery.paddingOf(context)),
                children: [
                  if (unfinishedDrill != null) ...[
                    ListSection(
                      margin: EdgeInsets.zero,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.play_arrow),
                          title: const Text(DrillStrings.resumeDrill),
                          subtitle: Text(
                            [
                              '${unfinishedDrill.results.length} / ${unfinishedDrill.config.nbPuzzles}',
                              drillAngleName(context, ref, unfinishedDrill.config.angle),
                              puzzleDifficultyL10n(context, unfinishedDrill.config.difficulty),
                            ].join(' · '),
                          ),
                          trailing: const Icon(Icons.keyboard_arrow_right),
                          onTap: _isStarting ? null : _resumeDrill,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24.0),
                  ],
                  const FilterTitle(DrillStrings.nbPuzzlesChoice),
                  // Spread across the width, in line with the slider below, unlike a [Filter]. Without
                  // a checkmark, a selected chip keeps its width and doesn't move the others.
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: .spaceBetween,
                      spacing: 8.0,
                      runSpacing: Theme.of(context).platform == .iOS ? 8.0 : 0.0,
                      children: [
                        for (final nb in _quickPickNbPuzzles)
                          PlatformChoiceChip(
                            label: Text('$nb'),
                            selected: nb == _config.nbPuzzles,
                            showCheckmark: false,
                            onSelected: (_) => _setNbPuzzles(nb),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: NonLinearSlider(
                          value: _config.nbPuzzles,
                          values: _sliderNbPuzzles,
                          onChange: (nb) => _setNbPuzzles(nb.toInt()),
                          // The number of puzzles is already set while dragging.
                          onChangeEnd: (_) {},
                        ),
                      ),
                      SizedBox(
                        width: 40.0,
                        child: Text(
                          '${_config.nbPuzzles}',
                          textAlign: .end,
                          style: TextTheme.of(context).titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  ListSection(
                    margin: EdgeInsets.zero,
                    children: [
                      ListTile(
                        title: const Text(DrillStrings.theme),
                        subtitle: Text(drillAngleName(context, ref, _config.angle)),
                        trailing: const Icon(Icons.keyboard_arrow_right),
                        onTap: _chooseAngle,
                      ),
                      SettingsListTile(
                        settingsLabel: Text(context.l10n.puzzleDifficultyLevel),
                        settingsValue: puzzleDifficultyL10n(context, _config.difficulty),
                        onTap: () => showChoicePicker(
                          context,
                          choices: PuzzleDifficulty.values,
                          selectedItem: _config.difficulty,
                          labelBuilder: (d) => Text(puzzleDifficultyL10n(context, d)),
                          onSelectedItemChanged: (d) =>
                              setState(() => _config = _config.copyWith(difficulty: d)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24.0),
                  PlatformFilledButton(
                    onPressed: _isStarting
                        ? null
                        : unfinishedDrill != null
                        // A new Drill ends the unfinished one.
                        ? () => showConfirmDialog<void>(
                            context,
                            title: const Text(DrillStrings.replaceUnfinishedDrillConfirmation),
                            onConfirm: _startDrill,
                          )
                        : _startDrill,
                    child: _isStarting
                        ? const ButtonLoadingIndicator()
                        : const Text(DrillStrings.startDrill),
                  ),
                  const SizedBox(height: 12.0),
                  // A warm-up before the Drill: Puzzle Storm as in the official app, which counts
                  // neither on the puzzle rating nor in the Drill.
                  OutlinedButton.icon(
                    icon: const Icon(LichessIcons.storm),
                    label: const Text(DrillStrings.warmUpWithStorm),
                    onPressed: isOnline
                        ? () => Navigator.of(context).push(StormScreen.buildRoute())
                        : null,
                  ),
                ],
              ),
            )
          : Center(
              child: Padding(
                padding: Styles.bodyPadding,
                child: Column(
                  mainAxisSize: .min,
                  children: [
                    Text(
                      DrillStrings.homeSignInPrompt,
                      textAlign: .center,
                      style: TextTheme.of(context).bodyLarge,
                    ),
                    const SizedBox(height: 24.0),
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
