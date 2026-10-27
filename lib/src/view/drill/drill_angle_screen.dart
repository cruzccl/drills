import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/drill/drill_controller.dart';
import 'package:lichess_mobile/src/model/drill/drill_history.dart';
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
import 'package:lichess_mobile/src/widgets/platform_choice_chip.dart';
import 'package:material_ui/material_ui.dart';

/// The name of the theme or opening of a Drill.
String drillAngleName(BuildContext context, WidgetRef ref, PuzzleAngle angle) => switch (angle) {
  PuzzleTheme(:final themeKey) => themeKey.l10n(context.l10n).name,
  PuzzleOpening(:final key) =>
    ref.watch(puzzleOpeningNameProvider(key)).value ?? key.replaceAll('_', ' '),
};

/// The most themes and openings of the latest Drills offered again.
const _maxRecentAngles = 3;

/// Chooses the theme or opening of a Drill, which its route returns.
///
/// The themes to work on, those most failed in the latest Drills, come first, then the themes and
/// openings of the latest Drills, then all of them. Unlike the upstream puzzle themes screen, it
/// offers the healthy mix too, and needs a connection for the openings: a Drill downloads its
/// puzzles when it starts.
class const DrillAngleScreen({required final PuzzleAngle selected, super.key})
    extends ConsumerWidget {
  static Route<PuzzleAngle> buildRoute(PuzzleAngle selected) {
    return buildScreenRoute(screen: DrillAngleScreen(selected: selected));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(puzzleThemeCategoriesProvider);
    final weakThemes = [
      for (final weak
          in ref.watch(recentWeakestThemesProvider).value ?? const IListConst<DrillWeakTheme>([]))
        if (puzzleThemeNameMap.get(weak.theme) case final key?) (key: key, data: weak),
    ];
    final recentAngles = (ref.watch(drillHistoryProvider).value?.entries ?? const IListConst([]))
        .map((e) => e.config.angle)
        .toSet()
        .take(_maxRecentAngles)
        .toList();
    final subtitleStyle = TextStyle(
      fontSize: 13,
      color: textShade(context, Styles.subtitleOpacity),
    );

    return PlatformScaffold(
      appBar: PlatformAppBar(title: Text(context.l10n.puzzlePuzzleThemes)),
      body: ListView(
        children: [
          if (weakThemes.isNotEmpty)
            ListSection(
              hasLeading: true,
              header: Column(
                crossAxisAlignment: .start,
                spacing: 2.0,
                children: [
                  Text(context.drillL10n.toWorkOn),
                  Text(context.drillL10n.toWorkOnHint, style: subtitleStyle),
                ],
              ),
              children: [
                for (final (:key, :data) in weakThemes)
                  _WeakThemeTile(theme: key, data: data, selected: selected),
              ],
            ),
          if (recentAngles.isNotEmpty)
            Padding(
              padding: Styles.horizontalBodyPadding.add(Styles.sectionTopPadding),
              child: Column(
                crossAxisAlignment: .start,
                spacing: 10.0,
                children: [
                  Text(context.drillL10n.recentThemes, style: Styles.sectionTitle),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: Theme.of(context).platform == .iOS ? 8.0 : 0.0,
                    children: [
                      for (final angle in recentAngles)
                        PlatformChoiceChip(
                          label: Text(drillAngleName(context, ref, angle)),
                          selected: angle == selected,
                          onSelected: (_) => Navigator.of(context).pop(angle),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          // The recommended category is the healthy mix alone.
          ListSection(
            header: weakThemes.isNotEmpty || recentAngles.isNotEmpty
                ? Text(context.drillL10n.allThemes)
                : null,
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

/// A theme to work on: how many of its puzzles of the latest Drills were failed, as a bar too.
class const _WeakThemeTile({
  required final PuzzleThemeKey theme,
  required final DrillWeakTheme data,
  required final PuzzleAngle selected,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final share = data.puzzles == 0 ? 0.0 : data.failures / data.puzzles;
    final colors = context.lichessColors;
    return ListTile(
      leading: Icon(theme.icon),
      title: Row(
        spacing: 8.0,
        children: [
          Expanded(child: Text(theme.l10n(context.l10n).name, overflow: .ellipsis)),
          Text(
            context.drillL10n.failedOfTotal(data.failures, data.puzzles),
            style: TextStyle(fontSize: 13, color: textShade(context, Styles.subtitleOpacity)),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6.0),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(3.0)),
          child: LinearProgressIndicator(
            value: share,
            minHeight: 6.0,
            color: share >= 0.5 ? colors.error : colors.brag,
            backgroundColor: ColorScheme.of(context).outlineVariant,
          ),
        ),
      ),
      trailing: selected == PuzzleTheme(theme)
          ? Icon(Icons.check, color: ColorScheme.of(context).primary)
          : null,
      onTap: () => Navigator.of(context).pop(PuzzleTheme(theme)),
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
