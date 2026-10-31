import 'package:flutter_test/flutter_test.dart';
import 'package:lichess_mobile/src/view/drill/drill_summary.dart';

void main() {
  group('formatSolvingTime', () {
    test('shows minutes and seconds under one hour', () {
      expect(formatSolvingTime(Duration.zero), '0:00');
      expect(formatSolvingTime(const Duration(minutes: 2, seconds: 5)), '2:05');
      expect(formatSolvingTime(const Duration(minutes: 59, seconds: 59)), '59:59');
    });

    test('shows hours, minutes and seconds from one hour on', () {
      expect(formatSolvingTime(const Duration(hours: 1)), '1:00:00');
      expect(formatSolvingTime(const Duration(hours: 3, minutes: 10, seconds: 13)), '3:10:13');
      expect(formatSolvingTime(const Duration(hours: 12, minutes: 5, seconds: 7)), '12:05:07');
    });
  });
}
