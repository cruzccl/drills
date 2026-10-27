import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lichess_mobile/l10n/drill/drill_localizations.dart';
import 'package:lichess_mobile/src/model/drill/drill_history.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_angle.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_difficulty.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/view/drill/drill_angle_screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_summary.dart';
import 'package:lichess_mobile/src/widgets/adaptive_action_sheet.dart';
import 'package:lichess_mobile/src/widgets/feedback.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';
import 'package:lichess_mobile/src/widgets/platform_context_menu_button.dart';
import 'package:material_ui/material_ui.dart';

/// How far from the end of the list the next page of older Drills is loaded.
const _loadMoreExtent = 600.0;

/// The Drill History: the past Drills, newest first and grouped by day. Their charts are on the
/// Drill Progress screen.
///
/// A Drill is opened on its Drill Summary, and deleted with a long press. The Drill History of
/// every account on the device is saved to a file, and imported back, from the app bar menu.
///
/// Its route returns the weakest theme of a Drill Summary the player tapped, to set up a Drill
/// with.
class const DrillHistoryScreen({super.key}) extends ConsumerWidget {
  static Route<PuzzleAngle> buildRoute() {
    return buildScreenRoute(screen: const DrillHistoryScreen());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(drillHistoryProvider);
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(context.drillL10n.historyTitle),
        largeTitle: true,
        actions: const [_HistoryMenu()],
      ),
      body: switch (history) {
        AsyncData(value: DrillHistoryState(:final entries)) when entries.isEmpty => Center(
          child: Padding(padding: Styles.bodyPadding, child: Text(context.drillL10n.emptyHistory)),
        ),
        AsyncData(value: DrillHistoryState(:final entries, :final hasMore)) =>
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (hasMore && notification.metrics.extentAfter < _loadMoreExtent) {
                ref.read(drillHistoryProvider.notifier).loadMore();
              }
              return false;
            },
            // The body's own context: the padding of the screen's isn't the one inside the scaffold.
            child: Builder(
              builder: (context) => ListView(
                padding: Styles.bodyPadding.add(MediaQuery.paddingOf(context)),
                children: [
                  for (final (day, dayEntries) in _groupByDay(entries)) ...[
                    _DayHeader(day, dayEntries),
                    for (final entry in dayEntries) ...[
                      _DrillCard(entry),
                      const SizedBox(height: 10.0),
                    ],
                    const SizedBox(height: 14.0),
                  ],
                  if (hasMore) const Center(child: CircularProgressIndicator.adaptive()),
                ],
              ),
            ),
          ),
        AsyncError() => const Center(child: Text('Could not load the Drill History')),
        _ => const Center(child: CircularProgressIndicator.adaptive()),
      },
    );
  }
}

/// A provider for picking a Drill History file to import. Can be overridden in tests.
final pickDrillHistoryFileProvider = Provider<Future<PlatformFile?> Function()>((ref) {
  return () => FilePicker.pickFile(type: .custom, allowedExtensions: ['json']);
});

/// A provider for saving a Drill History file where the player chooses, returning where it was
/// saved, or `null` if they cancelled. Can be overridden in tests.
final saveDrillHistoryFileProvider =
    Provider<Future<Uri?> Function(String fileName, Uint8List bytes)>((ref) {
      return (fileName, bytes) => FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/json',
        type: .custom,
        allowedExtensions: ['json'],
      );
    });

/// The app bar menu of the Drill History: exporting it to a file, and importing one.
class const _HistoryMenu() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ContextMenuIconButton(
      semanticsLabel: context.drillL10n.historyMenu,
      icon: const Icon(Icons.more_vert),
      actions: [
        ContextMenuAction(
          icon: Icons.upload_outlined,
          label: context.drillL10n.exportHistory,
          onPressed: () => _export(ref, SnackBarPresenter.of(context), context.drillL10n),
        ),
        ContextMenuAction(
          icon: Icons.download_outlined,
          label: context.drillL10n.importHistory,
          onPressed: () => _import(context, ref),
        ),
      ],
    );
  }

  /// Saves the Drill History file, named with the date, where the player chooses in the system
  /// save dialog: on the device or in a cloud storage such as Drive.
  Future<void> _export(WidgetRef ref, SnackBarPresenter snackBar, DrillLocalizations l10n) async {
    try {
      final json = await ref.read(drillHistoryProvider.notifier).exportDrills();
      final name = 'drills-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json';
      final uri = await ref.read(saveDrillHistoryFileProvider)(name, utf8.encode(json));
      if (uri != null) snackBar.show(l10n.historyExported);
    } catch (_) {
      snackBar.show(l10n.couldNotExportHistory, type: .error);
    }
  }

  /// Adds the Drills of a picked Drill History file, and says how many were added.
  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final snackBar = SnackBarPresenter.of(context);
    final l10n = context.drillL10n;
    try {
      final file = await ref.read(pickDrillHistoryFileProvider)();
      if (file == null) return;
      final json = await const Utf8Decoder().bind(file.readAsByteStream()).join();
      final (:added, :existing) = await ref.read(drillHistoryProvider.notifier).importDrills(json);
      snackBar.show(_importResultText(l10n, added: added, existing: existing));
    } on FormatException {
      snackBar.show(l10n.invalidHistoryFile, type: .error);
    } catch (_) {
      snackBar.show(l10n.couldNotImportHistory, type: .error);
    }
  }
}

/// What an import added to the Drill History, and what was already in it.
String _importResultText(DrillLocalizations l10n, {required int added, required int existing}) {
  return existing == 0
      ? l10n.drillsImported(added)
      : l10n.drillsImportedSomeInHistory(added, existing);
}

/// The Drills of [entries] grouped by the day they started, in order.
List<(DateTime, List<DrillHistoryEntry>)> _groupByDay(IList<DrillHistoryEntry> entries) => [
  for (final MapEntry(key: day, value: dayEntries) in groupBy(
    entries,
    (entry) => DateUtils.dateOnly(entry.startedAt),
  ).entries)
    (day, dayEntries),
];

/// A day of the Drill History: its date, how many Drills and puzzles were played and how much they
/// changed the player's rating.
class const _DayHeader(final DateTime day, final List<DrillHistoryEntry> entries)
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final changes = entries.map((e) => e.ratingChange).nonNulls;
    final change = changes.isEmpty ? null : changes.sum;
    final nb = entries.length;
    final nbPuzzles = entries.map((e) => e.nbPlayed).sum;
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, right: 4.0, bottom: 10.0),
      child: Row(
        crossAxisAlignment: .baseline,
        textBaseline: .alphabetic,
        children: [
          Expanded(child: Text(drillDayName(context, day), style: Styles.sectionTitle)),
          Text(
            '${context.drillL10n.nbDrills(nb)} · ${context.drillL10n.nbPuzzles(nbPuzzles)}'
            '${change != null ? ' · ' : ''}',
            style: TextStyle(fontSize: 13, color: textShade(context, Styles.subtitleOpacity)),
          ),
          if (change != null)
            Text(
              formatRatingChange(change),
              style: TextStyle(fontSize: 13, fontWeight: .bold, color: signColor(context, change)),
            ),
        ],
      ),
    );
  }
}

/// A Drill of the Drill History: what it was, its share of puzzles solved, Drill Performance and
/// rating change, then the result of each puzzle.
class const _DrillCard(final DrillHistoryEntry entry) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.lichessColors;
    final subtitleStyle = TextStyle(
      fontSize: 13,
      color: textShade(context, Styles.subtitleOpacity),
    );
    final config = entry.config;
    final ratingBefore = entry.ratingBefore?.toString() ?? '?';
    final ratingChange = entry.ratingChange;
    return Card(
      margin: .zero,
      clipBehavior: .antiAlias,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16.0))),
      child: InkWell(
        onTap: () async {
          final angle = await Navigator.of(context)
              .push(DrillHistorySummaryScreen.buildRoute(entry.startedAt));
          if (angle != null && context.mounted) Navigator.of(context).pop(angle);
        },
        onLongPress: () => showConfirmDialog<void>(
          context,
          title: Text(context.drillL10n.deleteDrillConfirmation),
          isDestructiveAction: true,
          onConfirm: () => ref.read(drillHistoryProvider.notifier).delete(entry.startedAt),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14.0, 14.0, 14.0, 12.0),
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              Row(
                spacing: 6.0,
                children: [
                  Expanded(
                    child: Text(
                      drillAngleName(context, ref, config.angle),
                      style: const TextStyle(fontSize: 17, fontWeight: .w500),
                      overflow: .ellipsis,
                    ),
                  ),
                  if (entry.isPartial)
                    _Badge(context.drillL10n.partial, color: colors.brag, textColor: Colors.black),
                ],
              ),
              const SizedBox(height: 4.0),
              Row(
                children: [
                  Text(DateFormat.Hm().format(entry.startedAt), style: subtitleStyle),
                  const SizedBox(width: 6.0),
                  Icon(Icons.timer_outlined, size: 14, color: subtitleStyle.color),
                  const SizedBox(width: 2.0),
                  Text(formatSolvingTime(entry.totalSolvingTime), style: subtitleStyle),
                  Flexible(
                    child: Text(
                      ' · ${puzzleDifficultyL10n(context, config.difficulty)}',
                      style: subtitleStyle,
                      overflow: .ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6.0),
                  DrillDifficultyDots(config.difficulty),
                ],
              ),
              const SizedBox(height: 12.0),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: .stretch,
                  spacing: 8.0,
                  children: [
                    _MetricTile(
                      label: context.drillL10n.successes,
                      value: '${(entry.successRate * 100).round()} %',
                      valueColor: successRateColor(
                        context,
                        entry.successRate,
                        entry.expectedSuccessRate,
                      ),
                      details: [
                        [
                          '${entry.successes} / ${entry.nbPlayed}',
                          if (entry.isPartial) context.drillL10n.ofTotal(config.nbPuzzles),
                        ].join(' · '),
                      ],
                    ),
                    _MetricTile(
                      label: context.drillL10n.performance,
                      value: entry.performance?.toString() ?? '-',
                      valueColor: colors.primary,
                      opacity: entry.isPerformanceReliable ? 1.0 : 0.55,
                      details: [if (!entry.isPerformanceReliable) context.drillL10n.unreliable],
                    ),
                    _MetricTile(
                      label: context.drillL10n.points,
                      value: ratingChange == null ? '···' : formatRatingChange(ratingChange),
                      valueColor: ratingChange == null
                          ? textShade(context, Styles.subtitleOpacity)
                          : signColor(context, ratingChange),
                      detail: Row(
                        mainAxisSize: .min,
                        spacing: 3.0,
                        children: [
                          Text(ratingBefore),
                          const Icon(Icons.arrow_forward, size: 12),
                          Text(entry.ratingAfter?.toString() ?? '?'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12.0),
              DrillResultsBar(entry),
            ],
          ),
        ),
      ),
    );
  }
}

/// The level of a difficulty among all of them, as dots: those up to it lit.
class const DrillDifficultyDots(final PuzzleDifficulty difficulty) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: .min,
      spacing: 2.0,
      children: [
        for (final level in PuzzleDifficulty.values)
          Container(
            width: 6.0,
            height: 6.0,
            decoration: BoxDecoration(
              shape: .circle,
              color: level.index <= difficulty.index
                  ? context.lichessColors.primary
                  : ColorScheme.of(context).outlineVariant,
            ),
          ),
      ],
    );
  }
}

/// The result of each puzzle of a Drill, in order, its puzzles not played left grey.
class const DrillResultsBar(final DrillHistoryEntry entry, {final double height = 6.0})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.lichessColors;
    return Row(
      spacing: 3.0,
      children: [
        for (var i = 0; i < entry.config.nbPuzzles; i++)
          Expanded(
            child: Container(
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(height / 2)),
                color: i >= entry.nbPlayed
                    ? ColorScheme.of(context).outlineVariant
                    : entry.wins[i]
                    ? colors.good
                    : colors.error,
              ),
            ),
          ),
      ],
    );
  }
}

/// One of the three figures of a [_DrillCard]: its label, value and details, centered.
class const _MetricTile({
  required final String label,
  required final String value,
  final Color? valueColor,
  final double opacity = 1.0,
  final List<String> details = const [],
  final Widget? detail,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final detailStyle = TextStyle(fontSize: 12, color: textShade(context, Styles.subtitleOpacity));
    return Expanded(
      child: Opacity(
        opacity: opacity,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
          decoration: BoxDecoration(
            color: ColorScheme.of(context).surfaceContainerLowest,
            borderRadius: const BorderRadius.all(Radius.circular(10.0)),
          ),
          child: Column(
            mainAxisAlignment: .center,
            spacing: 2.0,
            children: [
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: .ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.3,
                  color: textShade(context, Styles.subtitleOpacity),
                ),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 22, fontWeight: .bold, color: valueColor),
              ),
              for (final text in details) Text(text, textAlign: .center, style: detailStyle),
              if (detail != null) DefaultTextStyle.merge(style: detailStyle, child: detail!),
            ],
          ),
        ),
      ),
    );
  }
}

class const _Badge(final String text, {required final Color color, required final Color textColor})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.all(Radius.circular(10.0)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: .bold, color: textColor),
      ),
    );
  }
}

/// The Drill Summary of a past Drill, with its rating changes as they come.
///
/// Its route returns the weakest theme the player tapped.
class const DrillHistorySummaryScreen(final DateTime startedAt) extends ConsumerWidget {
  static Route<PuzzleAngle> buildRoute(DateTime startedAt) {
    return buildScreenRoute(screen: DrillHistorySummaryScreen(startedAt));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drill = ref.watch(drillHistoryDrillProvider(startedAt));
    return PlatformScaffold(
      appBar: PlatformAppBar(title: Text(context.drillL10n.summaryTitle)),
      body: switch (drill) {
        AsyncValue(value: final drill?) => DrillSummary(drill),
        AsyncData() || AsyncError() => const Center(child: Text('Could not load the Drill')),
        _ => const Center(child: CircularProgressIndicator.adaptive()),
      },
    );
  }
}

/// The name of the day of [date]: today, yesterday, or its date, with the year if it is not this
/// year's, and with the day of the week unless [short].
String drillDayName(BuildContext context, DateTime date, {bool short = false}) {
  final today = DateUtils.dateOnly(DateTime.now());
  final day = DateUtils.dateOnly(date);
  if (day == today) return context.drillL10n.today;
  if (day == today.subtract(const Duration(days: 1))) return context.drillL10n.yesterday;
  final format = day.year == today.year
      ? (short ? DateFormat.MMMd() : DateFormat.MMMEd())
      : (short ? DateFormat.yMMMd() : DateFormat.yMMMEd());
  final name = format.format(date);
  return name.isEmpty ? name : name[0].toUpperCase() + name.substring(1);
}
