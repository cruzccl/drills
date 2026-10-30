// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'drill_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class DrillLocalizationsEn extends DrillLocalizations {
  DrillLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get signedOutNotice => 'Signed out, Drills don\'t count on any Lichess account and aren\'t saved to the history. Sign in to have them count on yours.';

  @override
  String get nbPuzzlesChoice => 'Number of puzzles';

  @override
  String get theme => 'Theme';

  @override
  String get startDrill => 'Start';

  @override
  String get warmUpWithStorm => 'Warm up with Puzzle Storm';

  @override
  String get couldNotStartDrill => 'Could not load the puzzles.';

  @override
  String get resumeDrill => 'Resume the Drill';

  @override
  String get replaceUnfinishedDrillConfirmation => 'Start a new Drill? The unfinished one will be ended.';

  @override
  String get nextDrill => 'Your next Drill';

  @override
  String get nbPuzzlesTile => 'Puzzles';

  @override
  String get difficulty => 'Difficulty';

  @override
  String get sameAsLast => 'Same as last';

  @override
  String get toWorkOnTag => 'to work on';

  @override
  String lastNbPuzzles(int count) {
    return 'Last one: $count';
  }

  @override
  String get lastOneTag => 'last one';

  @override
  String get done => 'Done';

  @override
  String get onePuzzleLess => 'One puzzle less';

  @override
  String get onePuzzleMore => 'One puzzle more';

  @override
  String puzzlesLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'puzzles',
      one: 'puzzle',
    );
    return '$_temp0';
  }

  @override
  String estimatedTime(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return 'About $_temp0, at your pace in your last Drills';
  }

  @override
  String ratingBasis(int rating) {
    return 'Based on your puzzle rating, $rating';
  }

  @override
  String puzzlesOfAbout(int rating) {
    return 'Puzzles rated about $rating';
  }

  @override
  String puzzlesOfAboutLikeYou(int rating) {
    return 'Puzzles rated about $rating, like you';
  }

  @override
  String get streak => 'Streak';

  @override
  String daysInARow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'days in a row',
      one: 'day in a row',
    );
    return '$_temp0';
  }

  @override
  String bestStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return 'Your best streak: $_temp0';
  }

  @override
  String get bestStreakLabel => 'best streak';

  @override
  String get daysWithDrills => 'days with Drills';

  @override
  String playTodayToReach(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return 'Play a Drill today to reach $_temp0';
  }

  @override
  String get playTodayToStart => 'Play a Drill today to start a streak';

  @override
  String get progress => 'Progress';

  @override
  String get fewerPuzzles => 'Fewer';

  @override
  String get morePuzzles => 'More puzzles';

  @override
  String get lastDrills => 'Last Drills';

  @override
  String get seeHistory => 'See history';

  @override
  String get toWorkOn => 'To work on';

  @override
  String get toWorkOnHint => 'The themes you fail the most in your last 10 Drills';

  @override
  String failedOfTotal(int failures, int total) {
    return '$failures of $total failed';
  }

  @override
  String get recentThemes => 'Recent';

  @override
  String get allThemes => 'All themes';

  @override
  String get giveUp => 'Give up';

  @override
  String get previousMove => 'Previous';

  @override
  String get endDrill => 'End';

  @override
  String get endDrillConfirmation => 'End the Drill now?';

  @override
  String endPartialDrillWarning(int done, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'puzzles',
      one: 'puzzle',
    );
    return 'You have done $done of $total $_temp0. The Drill will be left incomplete and you won\'t be able to resume it.';
  }

  @override
  String get endEmptyDrillWarning => 'You haven\'t done any puzzle yet: the Drill will be discarded.';

  @override
  String get leaveDrillHint => 'If you leave with the back arrow, you can resume it later.';

  @override
  String get summaryTitle => 'Drill summary';

  @override
  String nbPuzzles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count puzzles',
      one: '1 puzzle',
    );
    return '$_temp0';
  }

  @override
  String get partial => 'Incomplete';

  @override
  String get successes => 'Successes';

  @override
  String nbSolvedOfTotal(int solved, int total) {
    return '$solved of $total solved';
  }

  @override
  String get betterThanExpected => 'Better than expected';

  @override
  String get worseThanExpected => 'Worse than expected';

  @override
  String get asExpected => 'As expected';

  @override
  String get time => 'Time';

  @override
  String get totalTime => 'Total';

  @override
  String get averageTime => 'Per puzzle';

  @override
  String get performance => 'Performance';

  @override
  String get unreliable => 'Unreliable';

  @override
  String get weakestThemes => 'Weakest themes';

  @override
  String get weakestThemesHint => 'Tap one to set up a Drill on that theme';

  @override
  String get train => 'Train';

  @override
  String themePuzzles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'All $count puzzles',
      one: 'The puzzle',
    );
    return '$_temp0';
  }

  @override
  String get unrated => 'unrated';

  @override
  String get pending => 'pending';

  @override
  String get backToHome => 'Back';

  @override
  String get historyTitle => 'Drill History';

  @override
  String get emptyHistory => 'You haven\'t finished any Drill yet.';

  @override
  String deleteDrillsConfirmation(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete these $count Drills from the history?',
      one: 'Delete this Drill from the history?',
    );
    return '$_temp0';
  }

  @override
  String nbSelected(int count) {
    return '$count selected';
  }

  @override
  String get analyzeDrills => 'Analyze';

  @override
  String get deleteDrills => 'Delete';

  @override
  String get selectSameDrillsHint => 'Select other Drills of the same theme and difficulty to analyze them together.';

  @override
  String get mixedDrillsHint => 'Only Drills of the same theme and difficulty are analyzed together.';

  @override
  String groupSummaryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Summary of $count Drills',
      one: 'Summary of 1 Drill',
    );
    return '$_temp0';
  }

  @override
  String get historyMenu => 'More options';

  @override
  String get exportHistory => 'Export';

  @override
  String get importHistory => 'Import';

  @override
  String get historyExported => 'History exported.';

  @override
  String get couldNotExportHistory => 'Could not export the history.';

  @override
  String get couldNotImportHistory => 'Could not import the history.';

  @override
  String get invalidHistoryFile => 'Not a valid Drill History file.';

  @override
  String drillsImported(int added) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added Drills added',
      one: '1 Drill added',
      zero: 'No Drill added',
    );
    return '$_temp0.';
  }

  @override
  String drillsImportedSomeInHistory(int added, int existing) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added Drills added',
      one: '1 Drill added',
      zero: 'No Drill added',
    );
    String _temp1 = intl.Intl.pluralLogic(
      existing,
      locale: localeName,
      other: '$existing were already in the history',
      one: '1 was already in the history',
    );
    return '$_temp0; $_temp1.';
  }

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get points => 'Points';

  @override
  String nbOfTotal(int count, int total) {
    return '$count of $total';
  }

  @override
  String ofTotal(int total) {
    return 'of $total';
  }

  @override
  String expectedPercent(int percent) {
    return 'expected $percent %';
  }

  @override
  String nbOfTotalExpectedPercent(int count, int total, int percent) {
    return '$count of $total, expected $percent %';
  }

  @override
  String get allDays => 'All';

  @override
  String get noChartData => 'No data';

  @override
  String changeSinceLastDay(String change) {
    return '$change over the previous day';
  }

  @override
  String changeSinceLastWeek(String change) {
    return '$change over the previous week';
  }

  @override
  String changeSinceLastMonth(String change) {
    return '$change over the previous month';
  }

  @override
  String changeSinceLastThreeMonths(String change) {
    return '$change over the previous 3 months';
  }

  @override
  String changeSinceLastYear(String change) {
    return '$change over the previous year';
  }

  @override
  String get aboveExpected => 'Above expected';

  @override
  String get withinExpected => 'Within expected';

  @override
  String get belowExpected => 'Below expected';

  @override
  String get byDay => 'by day';

  @override
  String get byWeek => 'by week';

  @override
  String get byMonth => 'by month';

  @override
  String weekOf(String date) {
    return 'Week of $date';
  }

  @override
  String nbDrills(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Drills',
      one: '1 Drill',
    );
    return '$_temp0';
  }

  @override
  String get rangeWeek => '1W';

  @override
  String get rangeMonth => '1M';

  @override
  String get rangeThreeMonths => '3M';

  @override
  String get rangeYear => '1Y';

  @override
  String get rangeAllTime => 'ALL';

  @override
  String get profile => 'My profile';

  @override
  String get puzzles => 'Puzzles';

  @override
  String get puzzleRating => 'Puzzle rating';

  @override
  String get highestRating => 'Highest';

  @override
  String get lowestRating => 'Lowest';

  @override
  String nbPlayed(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString played';
  }

  @override
  String highScoreNbRuns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count runs',
      one: '1 run',
    );
    return 'highscore · $_temp0';
  }

  @override
  String highScoreValue(int score) {
    return 'highscore $score';
  }

  @override
  String stormChartCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return 'Best score of each day played · $_temp0';
  }

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get showClock => 'Show clock';

  @override
  String get about => 'Drills is a personal, unofficial version of Lichess Mobile.\nThanks to Lichess for making chess free for everyone.';

  @override
  String get supportLichess => 'Support Lichess';
}
