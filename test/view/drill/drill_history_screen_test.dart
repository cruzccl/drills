import 'dart:convert';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/drill/drill_controller.dart';
import 'package:lichess_mobile/src/view/drill/drill_history_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../model/auth/fake_auth_storage.dart';
import '../../test_provider_scope.dart';

/// A [PlatformFile] backed by in-memory bytes, avoiding the need for a real file path in tests.
final class _FakePlatformFile({
  @override required final String name,
  required final Uint8List fileBytes,
}) extends PlatformFile {
  @override
  Uri get uri => Uri.file(name);

  /// [Never] is used as the return type so that no `package:cross_file` import is needed: the
  /// screen only ever reads the file as a byte stream.
  @override
  Never get xFile => throw UnimplementedError();

  @override
  Future<int> length() async => fileBytes.length;

  @override
  Future<Uint8List> readAsBytes() async => fileBytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(fileBytes);

  @override
  int? lengthSync() => fileBytes.length;
}

/// The Drill History screen of [fakeAuthUser], whose file picker picks [file], and where a file
/// is saved by [save].
Future<Widget> _makeApp(
  WidgetTester tester, {
  required String file,
  Future<Uri?> Function(String fileName, Uint8List bytes)? save,
}) => makeTestProviderScopeApp(
  tester,
  home: const DrillHistoryScreen(),
  authUser: fakeAuthUser,
  overrides: {
    pickDrillHistoryFileProvider: pickDrillHistoryFileProvider.overrideWithValue(
      () async => _FakePlatformFile(name: 'drills-2026-10-24.json', fileBytes: utf8.encode(file)),
    ),
    if (save != null)
      saveDrillHistoryFileProvider: saveDrillHistoryFileProvider.overrideWithValue(save),
  },
);

Future<void> _openMenuAction(WidgetTester tester, String action) async {
  await tester.tap(find.byTooltip('More options'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

Future<void> _import(WidgetTester tester) => _openMenuAction(tester, 'Import');

void main() {
  testWidgets('imports the Drills of a file and says how many were added', (tester) async {
    final file = jsonEncode({
      'version': 1,
      'drills': [
        {'userId': fakeAuthUser.user.id.value, 'drill': _drill.toJson()},
      ],
    });
    await tester.pumpWidget(await _makeApp(tester, file: file));
    await tester.pumpAndSettle();
    expect(find.text("You haven't finished any Drill yet."), findsOneWidget);

    await _import(tester);
    expect(find.text('1 Drill added.'), findsOneWidget);
    expect(find.text("You haven't finished any Drill yet."), findsNothing);

    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    await _import(tester);
    expect(find.text('No Drill added; 1 was already in the history.'), findsOneWidget);
  });

  testWidgets('exports the Drill History to a file saved where the player chooses', (tester) async {
    final file = jsonEncode({
      'version': 1,
      'drills': [
        {'userId': fakeAuthUser.user.id.value, 'drill': _drill.toJson()},
      ],
    });
    final saved = <String, Uint8List>{};
    await tester.pumpWidget(
      await _makeApp(
        tester,
        file: file,
        save: (fileName, bytes) async {
          saved[fileName] = bytes;
          return Uri.parse('content://downloads/$fileName');
        },
      ),
    );
    await tester.pumpAndSettle();
    await _import(tester);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();

    await _openMenuAction(tester, 'Export');

    expect(saved.keys.single, matches(RegExp(r'^drills-\d{4}-\d{2}-\d{2}\.json$')));
    expect(jsonDecode(utf8.decode(saved.values.single)), jsonDecode(file));
    expect(find.text('History exported.'), findsOneWidget);
  });

  testWidgets('says so when the file is not a Drill History file', (tester) async {
    await tester.pumpWidget(await _makeApp(tester, file: '{"version": 2, "drills": []}'));
    await tester.pumpAndSettle();

    await _import(tester);

    expect(find.text('Not a valid Drill History file.'), findsOneWidget);
    expect(find.text("You haven't finished any Drill yet."), findsOneWidget);
  });
}

/// An ended Drill of 2 puzzles, one solved.
final _drill = Drill(
  config: const DrillConfig(nbPuzzles: 2),
  startedAt: DateTime(2026, 10, 20, 9),
  ratingBefore: 1500,
  latestRating: 1500,
  results: [
    for (final (i, win) in [true, false].indexed)
      DrillPuzzleResult(
        id: PuzzleId('past$i'),
        puzzleRating: 1500,
        themes: const ISetConst({}),
        win: win,
        rated: true,
        solvingTime: const Duration(seconds: 10),
        ratingDiff: win ? 10 : -10,
      ),
  ].toIList(),
);
