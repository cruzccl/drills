import 'dart:convert';
import 'dart:math' as math;

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lichess_mobile/src/db/drill_database.dart';
import 'package:lichess_mobile/src/model/auth/auth_controller.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/drill/drill_controller.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle.dart';
import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart';

part 'drill_history.freezed.dart';
part 'drill_history.g.dart';

final _logger = Logger('DrillHistory');

const _tableName = 'drill_history';

/// The fewest Drills of the Drill History loaded at once, as the list is scrolled.
const kDrillHistoryPageSize = 30;

/// The version of the Drill History files written by [DrillHistory.exportDrills], the only one
/// [DrillHistory.importDrills] reads.
const kDrillHistoryFileVersion = 1;

/// How many Drills [DrillHistory.importDrills] added, and how many were already in the Drill
/// History.
typedef DrillImportResult = ({int added, int existing});

/// The Drill History of the signed in player: the summaries of their ended Drills, newest first,
/// or none while signed out.
///
/// The summaries are loaded a page at a time ([DrillHistory.loadMore]), whole days at once. Each
/// account has its own Drill History, kept on the device while signed out. The [DrillController]
/// adds the Drills as they end, then updates them as their rating changes come.
final drillHistoryProvider = AsyncNotifierProvider<DrillHistory, DrillHistoryState>(
  DrillHistory.new,
  name: 'DrillHistoryProvider',
);

/// The Drills of the Drill History loaded so far.
@freezed
sealed class DrillHistoryState with _$DrillHistoryState {
  const factory({
    /// The summaries of the Drills loaded, newest first.
    required IList<DrillHistoryEntry> entries,

    /// Whether older Drills are left to load.
    required bool hasMore,

    /// Counts the changes of the Drill History, the pages loaded left out.
    @Default(0) int revision,
  }) = _DrillHistoryState;
}

class DrillHistory() extends AsyncNotifier<DrillHistoryState> {
  /// The writes to the database, done one after the other: [recordRatingDiffs] reads Drills before
  /// writing them back, which a write made meanwhile would be lost to.
  Future<void> _writes = Future.value();

  bool _isLoadingMore = false;

  @override
  Future<DrillHistoryState> build() async {
    final userId = ref.watch(authControllerProvider.select((auth) => auth?.user.id));
    if (userId == null) return const DrillHistoryState(entries: IListConst([]), hasMore: false);
    final db = await ref.read(drillDatabaseProvider.future);
    await _fillSummaries(db);
    final (entries, hasMore) = await _fetchPage(db, userId, limit: kDrillHistoryPageSize);
    return DrillHistoryState(entries: entries, hasMore: hasMore);
  }

  /// Loads the next page of older Drills, if any.
  Future<void> loadMore() async {
    final current = state.value;
    final userId = ref.read(authControllerProvider)?.user.id;
    if (current == null || !current.hasMore || _isLoadingMore || userId == null) return;
    _isLoadingMore = true;
    try {
      final db = await ref.read(drillDatabaseProvider.future);
      final (older, hasMore) = await _fetchPage(
        db,
        userId,
        before: current.entries.lastOrNull?.startedAt,
        limit: kDrillHistoryPageSize,
      );
      if (!ref.mounted || state.value != current) return;
      state = AsyncData(current.copyWith(entries: current.entries.addAll(older), hasMore: hasMore));
    } catch (e, st) {
      _logger.warning('Failed to load the Drill History', e, st);
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Adds [drill] to the Drill History of the account [userId], as it ends.
  Future<void> add(UserId userId, Drill drill) => _write(userId, (db) async {
    await db.insert(_tableName, {
      'userId': userId.value,
      'startedAt': _key(drill.startedAt),
      ..._columns(drill),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });

  /// Replaces [drill] in the Drill History of the account [userId], unless it was deleted.
  Future<void> replace(UserId userId, Drill drill) =>
      _write(userId, (db) => _update(db, userId, drill));

  /// Removes the Drill started at [startedAt] from the Drill History of the signed in player.
  Future<void> delete(DateTime startedAt) async {
    final userId = ref.read(authControllerProvider)?.user.id;
    if (userId == null) return;
    await _write(userId, (db) async {
      await db.delete(
        _tableName,
        where: 'userId = ? AND startedAt = ?',
        whereArgs: [userId.value, _key(startedAt)],
      );
    });
  }

  /// Records the rating changes of the solutions sent in [rounds] in the Drills of the account
  /// [userId] that were left without them, but the Drill started at [except], and the rating a
  /// Drill started at from the player's [glicko] rating returned if it was not known.
  ///
  /// A Drill can be replaced while some of its solutions are still to send, such as one solved
  /// offline: they are sent with the next Drill's, which gets their rating changes.
  Future<void> recordRatingDiffs(
    UserId userId,
    IList<PuzzleRound>? rounds,
    PuzzleGlicko? glicko, {
    DateTime? except,
  }) {
    if (rounds == null || rounds.isEmpty) return Future.value();
    return _write(userId, (db) async {
      final rows = await db.query(
        _tableName,
        columns: ['data'],
        where: 'userId = ? AND ratingPending = 1',
        whereArgs: [userId.value],
      );
      for (final drill in rows.map((row) => _decodeDrill(row['data']! as String))) {
        if (drill == null || drill.startedAt == except) continue;
        final synced = drill.withRatingDiffs(rounds);
        if (synced == drill) continue;
        final withRatingBefore = drill.withRatingBeforeFrom(rounds, glicko);
        // Its latest rating, from before these solutions were sent, misses their rating changes.
        final latestRating = withRatingBefore.latestRating ?? withRatingBefore.ratingBefore;
        final ratingChange = synced.ratingDiffsTotal - drill.ratingDiffsTotal;
        await _update(
          db,
          userId,
          synced.copyWith(
            ratingBefore: withRatingBefore.ratingBefore,
            latestRating: latestRating != null ? latestRating + ratingChange : null,
          ),
        );
      }
    });
  }

  /// Every Drill of every account on the device, as the JSON of a Drill History file, to keep
  /// them elsewhere and give them back with [importDrills].
  Future<String> exportDrills() async {
    await _writes;
    final db = await ref.read(drillDatabaseProvider.future);
    final rows = await db.query(
      _tableName,
      columns: ['userId', 'data'],
      orderBy: 'userId, startedAt',
    );
    return jsonEncode({
      'version': kDrillHistoryFileVersion,
      'drills': [
        for (final row in rows)
          {'userId': row['userId'], 'drill': jsonDecode(row['data']! as String)},
      ],
    });
  }

  /// Adds the Drills of a Drill History file made by [exportDrills] to the Drill Histories of
  /// their accounts, but the ones already there, which are kept as they are.
  ///
  /// Throws a [FormatException] if [json] is not a Drill History file this version can read,
  /// leaving the Drill Histories unchanged.
  Future<DrillImportResult> importDrills(String json) async {
    final drills = _parseDrillHistoryFile(json);
    final database = ref.read(drillDatabaseProvider.future);
    final result = _writes.then((_) async {
      final db = await database;
      final counts = await db.transaction((txn) async {
        var added = 0;
        for (final (userId, drill) in drills) {
          final existing = await txn.query(
            _tableName,
            columns: ['startedAt'],
            where: 'userId = ? AND startedAt = ?',
            whereArgs: [userId.value, _key(drill.startedAt)],
          );
          if (existing.isNotEmpty) continue;
          await txn.insert(_tableName, {
            'userId': userId.value,
            'startedAt': _key(drill.startedAt),
            ..._columns(drill),
          });
          added++;
        }
        return (added: added, existing: drills.length - added);
      });
      final userId = ref.mounted ? ref.read(authControllerProvider)?.user.id : null;
      if (userId != null) await _refresh(db, userId);
      return counts;
    });
    _writes = result.then((_) {}, onError: (_) {});
    return await result;
  }

  /// Runs [write] after the previous writes, then reloads the Drills loaded.
  Future<void> _write(UserId userId, Future<void> Function(Database db) write) {
    // Read now, so that the write is done even if the Drill History is disposed meanwhile.
    final database = ref.read(drillDatabaseProvider.future);
    return _writes = _writes.then((_) async {
      try {
        final db = await database;
        await write(db);
        await _refresh(db, userId);
      } catch (e, st) {
        _logger.warning('Failed to update the Drill History', e, st);
      }
    });
  }

  /// Reloads the Drills loaded, if they are the signed in player's.
  Future<void> _refresh(Database db, UserId userId) async {
    bool isSignedIn() => ref.mounted && ref.read(authControllerProvider)?.user.id == userId;
    if (!isSignedIn()) return;
    final current = state.value;
    final (entries, hasMore) = await _fetchPage(
      db,
      userId,
      limit: math.max(kDrillHistoryPageSize, current?.entries.length ?? 0),
    );
    if (!isSignedIn()) return;
    state = AsyncData(
      DrillHistoryState(entries: entries, hasMore: hasMore, revision: (current?.revision ?? 0) + 1),
    );
  }
}

/// The full Drill of the signed in player started at a time, to show its Drill Summary, or `null`
/// if it is not in their Drill History.
///
/// It follows the changes of the Drill History, such as rating changes coming in.
final drillHistoryDrillProvider = FutureProvider.autoDispose.family<Drill?, DateTime>((
  ref,
  startedAt,
) async {
  final userId = ref.watch(authControllerProvider.select((auth) => auth?.user.id));
  ref.watch(drillHistoryProvider.select((history) => history.value?.revision));
  if (userId == null) return null;
  final db = await ref.read(drillDatabaseProvider.future);
  final rows = await db.query(
    _tableName,
    columns: ['data'],
    where: 'userId = ? AND startedAt = ?',
    whereArgs: [userId.value, _key(startedAt)],
  );
  final data = rows.firstOrNull?['data'] as String?;
  return data != null ? _decodeDrill(data) : null;
}, name: 'DrillHistoryDrillProvider');

/// How many of the latest Drills the themes to work on and the pace of the player are taken from.
const kRecentDrills = 10;

/// The latest [kRecentDrills] full Drills of the signed in player's Drill History, newest first,
/// or none while signed out.
///
/// It follows the changes of the Drill History.
final recentDrillsProvider = FutureProvider.autoDispose<IList<Drill>>((ref) async {
  final userId = ref.watch(authControllerProvider.select((auth) => auth?.user.id));
  ref.watch(drillHistoryProvider.select((history) => history.value?.revision));
  if (userId == null) return const IListConst([]);
  final db = await ref.read(drillDatabaseProvider.future);
  final rows = await db.query(
    _tableName,
    columns: ['data'],
    where: 'userId = ?',
    whereArgs: [userId.value],
    orderBy: 'startedAt DESC',
    limit: kRecentDrills,
  );
  return [for (final row in rows) ?_decodeDrill(row['data']! as String)].toIList();
}, name: 'RecentDrillsProvider');

/// The most themes to work on suggested from the latest Drills.
const kMaxRecentWeakestThemes = 4;

/// The themes to work on: the weakest themes of the puzzles of the latest [kRecentDrills] Drills
/// taken together, at most [kMaxRecentWeakestThemes] of them.
final recentWeakestThemesProvider = FutureProvider.autoDispose<IList<DrillWeakTheme>>((ref) async {
  final drills = await ref.watch(recentDrillsProvider.future);
  return weakestThemesOf(drills.expand((d) => d.results), max: kMaxRecentWeakestThemes);
}, name: 'RecentWeakestThemesProvider');

/// The values of every Drill of the signed in player's Drill History, oldest first, for the chart
/// above it.
final drillChartPointsProvider = FutureProvider.autoDispose<IList<DrillChartPoint>>((ref) async {
  final userId = ref.watch(authControllerProvider.select((auth) => auth?.user.id));
  ref.watch(drillHistoryProvider.select((history) => history.value?.revision));
  if (userId == null) return const IListConst([]);
  // Once the Drill History has filled the columns read here.
  await ref.read(drillHistoryProvider.future);
  final db = await ref.read(drillDatabaseProvider.future);
  final rows = await db.query(
    _tableName,
    columns: ['startedAt', 'nbPlayed', 'performance', 'successRate', 'expectedSuccessRate'],
    where: 'userId = ? AND summary IS NOT NULL',
    whereArgs: [userId.value],
    orderBy: 'startedAt ASC',
  );
  return [
    for (final row in rows)
      (
        startedAt: DateTime.parse(row['startedAt']! as String).toLocal(),
        nbPuzzles: row['nbPlayed']! as int,
        performance: row['performance'] as int?,
        successRate: (row['successRate'] as num?)?.toDouble() ?? 0,
        expectedSuccessRate: (row['expectedSuccessRate'] as num?)?.toDouble(),
      ),
  ].toIList();
}, name: 'DrillChartPointsProvider');

/// The values of a Drill drawn in the chart of the Drill History.
typedef DrillChartPoint = ({
  DateTime startedAt,

  /// The number of puzzles played.
  int nbPuzzles,
  int? performance,
  double successRate,
  double? expectedSuccessRate,
});

/// What the Drill History shows of a Drill: its configuration and results, without its puzzles.
@Freezed(fromJson: true, toJson: true)
sealed class const DrillHistoryEntry._() with _$DrillHistoryEntry {
  const factory({
    required DrillConfig config,
    required DateTime startedAt,

    /// Whether each puzzle solved was a success, in order.
    required IList<bool> wins,

    /// The player's rating when the Drill started, if known.
    int? ratingBefore,

    /// The player's rating once every result was synced, `null` until then.
    int? ratingAfter,

    /// See [Drill.ratingChange].
    int? ratingChange,
    int? performance,

    /// See [Drill.expectedSuccessRate].
    double? expectedSuccessRate,
    @Default(Duration.zero) Duration totalSolvingTime,
  }) = _DrillHistoryEntry;

  factory fromJson(Map<String, dynamic> json) => _$DrillHistoryEntryFromJson(json);

  factory of(Drill drill) => DrillHistoryEntry(
    config: drill.config,
    startedAt: drill.startedAt,
    wins: drill.results.map((r) => r.win).toIList(),
    ratingBefore: drill.ratingBefore,
    ratingAfter: drill.ratingAfter,
    ratingChange: drill.ratingChange,
    performance: drill.performance,
    expectedSuccessRate: drill.expectedSuccessRate,
    totalSolvingTime: drill.totalSolvingTime,
  );

  int get nbPlayed => wins.length;

  int get successes => wins.where((win) => win).length;

  /// The share of puzzles solved, from 0 to 1, or 0 if no puzzle was solved.
  double get successRate => wins.isEmpty ? 0 : successes / nbPlayed;

  /// Whether it is a Partial Drill.
  bool get isPartial => nbPlayed < config.nbPuzzles;

  bool get isPerformanceReliable => nbPlayed >= kMinReliableDrillPuzzles;
}

/// The columns of a Drill's row made from it, see `drill_database.dart`.
Map<String, Object?> _columns(Drill drill) {
  final entry = DrillHistoryEntry.of(drill);
  return {
    'data': jsonEncode(drill.toJson()),
    'summary': jsonEncode(entry.toJson()),
    'ratingPending': drill.hasPendingRatingDiff ? 1 : 0,
    'nbPlayed': entry.nbPlayed,
    'performance': entry.performance,
    'isPerformanceReliable': entry.isPerformanceReliable ? 1 : 0,
    'successRate': entry.successRate,
    'expectedSuccessRate': entry.expectedSuccessRate,
  };
}

Future<void> _update(Database db, UserId userId, Drill drill) async {
  await db.update(
    _tableName,
    _columns(drill),
    where: 'userId = ? AND startedAt = ?',
    whereArgs: [userId.value, _key(drill.startedAt)],
  );
}

/// Fills the columns made from a Drill's `data` in the rows that don't have them yet, kept before
/// they existed.
Future<void> _fillSummaries(Database db) async {
  final rows = await db.query(
    _tableName,
    columns: ['userId', 'startedAt', 'data'],
    where: 'summary IS NULL',
  );
  if (rows.isEmpty) return;
  final batch = db.batch();
  for (final row in rows) {
    final drill = _decodeDrill(row['data']! as String);
    if (drill == null) continue;
    batch.update(
      _tableName,
      _columns(drill),
      where: 'userId = ? AND startedAt = ?',
      whereArgs: [row['userId'], row['startedAt']],
    );
  }
  await batch.commit(noResult: true);
}

/// Fetches at least [limit] summaries of the Drills of [userId] started before [before], newest
/// first, and the rest of the day of the last one, so that a day is never split across pages.
///
/// Returns them, and whether older Drills are left.
Future<(IList<DrillHistoryEntry>, bool)> _fetchPage(
  Database db,
  UserId userId, {
  DateTime? before,
  required int limit,
}) async {
  Future<List<Map<String, Object?>>> query(String where, List<Object?> whereArgs, {int? limit}) =>
      db.query(
        _tableName,
        columns: ['startedAt', 'summary'],
        where: 'userId = ? AND summary IS NOT NULL${where.isEmpty ? '' : ' AND $where'}',
        whereArgs: [userId.value, ...whereArgs],
        orderBy: 'startedAt DESC',
        limit: limit,
      );

  final rows = [
    ...await query(before != null ? 'startedAt < ?' : '', [
      if (before != null) _key(before),
    ], limit: limit),
  ];
  if (rows.length == limit) {
    final lastKey = rows.last['startedAt']! as String;
    final lastStart = DateTime.parse(lastKey).toLocal();
    final dayStart = DateTime(lastStart.year, lastStart.month, lastStart.day);
    rows.addAll(await query('startedAt < ? AND startedAt >= ?', [lastKey, _key(dayStart)]));
  }
  final hasMore =
      rows.isNotEmpty &&
      (await query('startedAt < ?', [rows.last['startedAt']], limit: 1)).isNotEmpty;
  final entries = [for (final row in rows) ?_decodeEntry(row['summary']! as String)].toIList();
  return (entries, hasMore);
}

/// The Drills of a Drill History file and their accounts, see [DrillHistory.exportDrills].
///
/// Throws a [FormatException] if [json] is not a Drill History file of this version.
List<(UserId, Drill)> _parseDrillHistoryFile(String json) {
  try {
    final file = jsonDecode(json);
    if (file case {'version': final int version, 'drills': final List<dynamic> drills}) {
      if (version != kDrillHistoryFileVersion) {
        throw FormatException('Unknown Drill History file version: $version');
      }
      return [
        for (final entry in drills)
          switch (entry) {
            {'userId': final String userId, 'drill': final Map<String, dynamic> drill} => (
              UserId(userId),
              Drill.fromJson(drill),
            ),
            _ => throw const FormatException('Not a Drill of a Drill History file'),
          },
      ];
    }
    throw const FormatException('Not a Drill History file');
  } on FormatException {
    rethrow;
  } catch (e) {
    // A Drill that doesn't decode.
    throw FormatException('Not a Drill History file: $e');
  }
}

/// A Drill's key in its account's Drill History: when it started, which also sorts them.
String _key(DateTime startedAt) => startedAt.toUtc().toIso8601String();

Drill? _decodeDrill(String data) {
  try {
    return Drill.fromJson(jsonDecode(data) as Map<String, dynamic>);
  } catch (e, st) {
    _logger.warning('Failed to decode a Drill of the Drill History', e, st);
    return null;
  }
}

DrillHistoryEntry? _decodeEntry(String summary) {
  try {
    return DrillHistoryEntry.fromJson(jsonDecode(summary) as Map<String, dynamic>);
  } catch (e, st) {
    _logger.warning('Failed to decode a Drill of the Drill History', e, st);
    return null;
  }
}
