import 'package:flutter/widgets.dart';
import 'package:lichess_mobile/l10n/drill/drill_localizations.dart';
import 'package:lichess_mobile/l10n/l10n.dart';

extension LocalizedBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// The UI text of Drills, which isn't part of the Lichess translations.
  DrillLocalizations get drillL10n => DrillLocalizations.of(this);
}

/// Loads [DrillLocalizations] in the locale of the app, or in English when Drills isn't translated
/// into it: the app follows the Lichess translations, in many more languages than Drills.
class const DrillLocalizationsDelegate() extends LocalizationsDelegate<DrillLocalizations> {
  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<DrillLocalizations> load(Locale locale) => DrillLocalizations.delegate.load(
    DrillLocalizations.delegate.isSupported(locale) ? locale : const Locale('en'),
  );

  @override
  bool shouldReload(DrillLocalizationsDelegate old) => false;
}
