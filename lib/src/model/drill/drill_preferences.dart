import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lichess_mobile/src/model/drill/drill_controller.dart';
import 'package:lichess_mobile/src/model/settings/preferences_storage.dart';

part 'drill_preferences.freezed.dart';
part 'drill_preferences.g.dart';

/// The settings of Drills that are not shared with the upstream puzzles.
final drillPreferencesProvider = NotifierProvider<DrillPreferences, DrillPrefs>(
  DrillPreferences.new,
  name: 'DrillPreferencesProvider',
);

class DrillPreferences() extends Notifier<DrillPrefs> with PreferencesStorage<DrillPrefs> {
  @override
  @protected
  PrefCategory get prefCategory => PrefCategory.drillSettings;

  @override
  @protected
  DrillPrefs get defaults => const DrillPrefs();

  @override
  DrillPrefs fromJson(Map<String, dynamic> json) => DrillPrefs.fromJson(json);

  @override
  DrillPrefs build() => fetch();

  Future<void> setShowClock(bool showClock) => save(state.copyWith(showClock: showClock));

  Future<void> setExtension(int nbPuzzles) => save(state.copyWith(extension: nbPuzzles));
}

@Freezed(fromJson: true, toJson: true)
sealed class DrillPrefs with _$DrillPrefs implements Serializable {
  const factory({
    /// Whether the Drill screen shows the time spent on the puzzle being solved.
    @Default(false) bool showClock,

    /// The number of puzzles to extend a Drill with from its Drill Summary: the last chosen.
    @Default(kDefaultDrillExtension) int extension,
  }) = _DrillPrefs;

  factory fromJson(Map<String, dynamic> json) => _$DrillPrefsFromJson(json);
}
