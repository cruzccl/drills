import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _kDrillDatabaseName = 'drills.db';

/// A provider for the database of Drills.
///
/// It is apart from the app database (`databaseProvider`), whose tables and versions are
/// upstream's: Lichess doesn't keep the Drill History, so it must survive upstream schema changes,
/// and outlive the entries the app database deletes after a while. Its file (`drills.db`) is in
/// Android Auto Backup, see `backup_rules.xml` and `data_extraction_rules.xml`.
final drillDatabaseProvider = FutureProvider<Database>((Ref ref) async {
  if (Platform.isLinux) {
    databaseFactory = databaseFactoryFfi;
  }
  final dbPath = Platform.isLinux
      ? join((await getApplicationSupportDirectory()).path, _kDrillDatabaseName)
      : join(await getDatabasesPath(), _kDrillDatabaseName);
  return await openDrillDatabase(databaseFactory, dbPath);
}, name: 'DrillDatabaseProvider');

/// Opens the database of Drills.
///
/// Without [singleInstance], an in-memory database is not shared with the other in-memory
/// databases, such as the app database in tests.
Future<Database> openDrillDatabase(
  DatabaseFactory dbFactory,
  String path, {
  bool singleInstance = true,
}) {
  return dbFactory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 2,
      singleInstance: singleInstance,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE drill_history(
            userId TEXT NOT NULL,
            startedAt TEXT NOT NULL,
            data TEXT NOT NULL,
            $_summaryColumns,
            PRIMARY KEY (userId, startedAt)
          )
          ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Filled in from `data` by the Drill History when it first reads them.
          for (final column in _summaryColumns.split(',')) {
            await db.execute('ALTER TABLE drill_history ADD COLUMN ${column.trim()}');
          }
        }
      },
    ),
  );
}

/// The columns of the Drill History made from a Drill's `data`, so that its list and chart are read
/// without decoding every Drill: its summary in the list, as JSON, and its values in the chart.
const _summaryColumns = '''
  summary TEXT,
  ratingPending INTEGER NOT NULL DEFAULT 0,
  performance INTEGER,
  isPerformanceReliable INTEGER NOT NULL DEFAULT 0,
  successRate REAL,
  expectedSuccessRate REAL,
  ratingAfter INTEGER''';
