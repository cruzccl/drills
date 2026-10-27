import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';

void main() {
  group('DrillLocalizationsDelegate', () {
    const delegate = DrillLocalizationsDelegate();

    test('loads the Drills translation of the locale', () async {
      expect((await delegate.load(const Locale('es'))).resumeDrill, 'Reanudar el Drill');
      expect((await delegate.load(const Locale('eu'))).resumeDrill, 'Jarraitu Drillarekin');
    });

    test('falls back to English in a locale Drills is not translated into', () async {
      expect(delegate.isSupported(const Locale('de')), isTrue);
      expect((await delegate.load(const Locale('de'))).resumeDrill, 'Resume the Drill');
    });
  });
}
