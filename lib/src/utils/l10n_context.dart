import 'package:flutter/widgets.dart';
import 'package:lichess_mobile/l10n/drill/drill_localizations.dart';
import 'package:lichess_mobile/l10n/l10n.dart';

extension LocalizedBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// The UI text of Drills, which isn't part of the Lichess translations.
  DrillLocalizations get drillL10n => DrillLocalizations.of(this);
}
