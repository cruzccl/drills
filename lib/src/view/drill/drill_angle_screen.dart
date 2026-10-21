import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_angle.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_opening.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_providers.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_theme.dart';
import 'package:lichess_mobile/src/styles/puzzle_icons.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/widgets/list.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';
import 'package:material_ui/material_ui.dart';

/// The name of the theme or opening of a Drill.
String drillAngleName(BuildContext context, WidgetRef ref, PuzzleAngle angle) => switch (angle) {
  PuzzleTheme(:final themeKey) => themeKey.l10n(context.l10n).name,
  PuzzleOpening(:final key) =>
    ref.watch(puzzleOpeningNameProvider(key)).value ?? key.replaceAll('_', ' '),
};

/// Chooses the theme or opening of a Drill, which its route returns.
///
/// Unlike the upstream puzzle themes screen, it offers the healthy mix too, and needs a connection
/// for the openings: a Drill downloads its puzzles when it starts.
class const DrillAngleScreen({required final PuzzleAngle selected, super.key})
    extends ConsumerWidget {
  static Route<PuzzleAngle> buildRoute(PuzzleAngle selected) {
    return buildScreenRoute(screen: DrillAngleScreen(selected: selected));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(puzzleThemeCategoriesProvider);

    return PlatformScaffold(
      appBar: PlatformAppBar(title: Text(context.l10n.puzzlePuzzleThemes)),
      body: ListView(
        children: [
          // The recommended category is the healthy mix alone.
          ListSection(
            hasLeading: true,
            children: [
              for (final t in categories.first.$2) _ThemeTile(theme: t, selected: selected),
            ],
          ),
          ListTile(
            leading: const Icon(PuzzleIcons.opening),
            title: Text(context.l10n.puzzleByOpenings),
            subtitle: selected is PuzzleOpening
                ? Text(drillAngleName(context, ref, selected))
                : null,
            trailing: const Icon(Icons.keyboard_arrow_right),
            onTap: () async {
              final opening = await Navigator.of(context)
                  .push(_DrillOpeningScreen.buildRoute(selected));
              if (opening != null && context.mounted) Navigator.of(context).pop(opening);
            },
          ),
          for (final (name, themes) in categories.skip(1))
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(name),
                initiallyExpanded: themes.any((t) => selected == PuzzleTheme(t)),
                children: [
                  ListSection(
                    hasLeading: true,
                    children: [for (final t in themes) _ThemeTile(theme: t, selected: selected)],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class const _DrillOpeningScreen({required final PuzzleAngle selected}) extends ConsumerWidget {
  static Route<PuzzleAngle> buildRoute(PuzzleAngle selected) {
    return buildScreenRoute(screen: _DrillOpeningScreen(selected: selected));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openings = ref.watch(puzzleOpeningsProvider(PuzzleOpeningSort.popular));

    return PlatformScaffold(
      appBar: PlatformAppBar(title: Text(context.l10n.puzzlePuzzlesByOpenings)),
      body: switch (openings) {
        AsyncData(:final value) => ListView(
          children: [
            for (final family in value)
              if (family.openings.isEmpty)
                _OpeningTile(
                  openingKey: family.key,
                  name: family.name,
                  count: family.count,
                  selected: selected,
                )
              else
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text(family.name, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${family.count}',
                      style: TextStyle(color: textShade(context, Styles.subtitleOpacity)),
                    ),
                    children: [
                      ListSection(
                        children: [
                          _OpeningTile(
                            openingKey: family.key,
                            name: family.name,
                            count: family.count,
                            selected: selected,
                          ),
                          for (final opening in family.openings)
                            _OpeningTile(
                              openingKey: opening.key,
                              name: opening.name,
                              count: opening.count,
                              selected: selected,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
          ],
        ),
        AsyncError() => const Center(child: Text('Could not load openings.')),
        _ => const Center(child: CircularProgressIndicator.adaptive()),
      },
    );
  }
}

class const _ThemeTile({required final PuzzleThemeKey theme, required final PuzzleAngle selected})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(theme.icon),
      title: Text(theme.l10n(context.l10n).name),
      trailing: selected == PuzzleTheme(theme)
          ? Icon(Icons.check, color: ColorScheme.of(context).primary)
          : null,
      onTap: () => Navigator.of(context).pop(PuzzleTheme(theme)),
    );
  }
}

class const _OpeningTile({
  required final String openingKey,
  required final String name,
  required final int count,
  required final PuzzleAngle selected,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(name, overflow: TextOverflow.ellipsis),
      subtitle: Text('$count', style: TextStyle(color: textShade(context, Styles.subtitleOpacity))),
      trailing: selected == PuzzleOpening(openingKey)
          ? Icon(Icons.check, color: ColorScheme.of(context).primary)
          : null,
      onTap: () => Navigator.of(context).pop(PuzzleOpening(openingKey)),
    );
  }
}
