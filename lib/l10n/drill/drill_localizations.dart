import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'drill_localizations_en.dart';
import 'drill_localizations_es.dart';
import 'drill_localizations_eu.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of DrillLocalizations
/// returned by `DrillLocalizations.of(context)`.
///
/// Applications need to include `DrillLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'drill/drill_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: DrillLocalizations.localizationsDelegates,
///   supportedLocales: DrillLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the DrillLocalizations.supportedLocales
/// property.
abstract class DrillLocalizations {
  DrillLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static DrillLocalizations of(BuildContext context) {
    return Localizations.of<DrillLocalizations>(context, DrillLocalizations)!;
  }

  static const LocalizationsDelegate<DrillLocalizations> delegate = _DrillLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('eu')
  ];

  /// No description provided for @signedOutNotice.
  ///
  /// In en, this message translates to:
  /// **'Signed out, Drills don\'t count on any Lichess account and aren\'t saved to the history. Sign in to have them count on yours.'**
  String get signedOutNotice;

  /// No description provided for @nbPuzzlesChoice.
  ///
  /// In en, this message translates to:
  /// **'Number of puzzles'**
  String get nbPuzzlesChoice;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @startDrill.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startDrill;

  /// No description provided for @warmUpWithStorm.
  ///
  /// In en, this message translates to:
  /// **'Warm up with Puzzle Storm'**
  String get warmUpWithStorm;

  /// No description provided for @couldNotStartDrill.
  ///
  /// In en, this message translates to:
  /// **'Could not load the puzzles.'**
  String get couldNotStartDrill;

  /// No description provided for @resumeDrill.
  ///
  /// In en, this message translates to:
  /// **'Resume the Drill'**
  String get resumeDrill;

  /// No description provided for @replaceUnfinishedDrillConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Start a new Drill? The unfinished one will be ended.'**
  String get replaceUnfinishedDrillConfirmation;

  /// No description provided for @nextDrill.
  ///
  /// In en, this message translates to:
  /// **'Your next Drill'**
  String get nextDrill;

  /// No description provided for @nbPuzzlesTile.
  ///
  /// In en, this message translates to:
  /// **'Puzzles'**
  String get nbPuzzlesTile;

  /// No description provided for @difficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get difficulty;

  /// No description provided for @sameAsLast.
  ///
  /// In en, this message translates to:
  /// **'Same as last'**
  String get sameAsLast;

  /// Tag next to a theme that is one of the themes to work on
  ///
  /// In en, this message translates to:
  /// **'to work on'**
  String get toWorkOnTag;

  /// The number of puzzles of the last Drill, in the number of puzzles picker
  ///
  /// In en, this message translates to:
  /// **'Last one: {count}'**
  String lastNbPuzzles(int count);

  /// Tag next to the difficulty of the last Drill
  ///
  /// In en, this message translates to:
  /// **'last one'**
  String get lastOneTag;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @onePuzzleLess.
  ///
  /// In en, this message translates to:
  /// **'One puzzle less'**
  String get onePuzzleLess;

  /// No description provided for @onePuzzleMore.
  ///
  /// In en, this message translates to:
  /// **'One puzzle more'**
  String get onePuzzleMore;

  /// Below the number of puzzles of the picker, shown large above it
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{puzzle} other{puzzles}}'**
  String puzzlesLabel(int count);

  /// No description provided for @estimatedTime.
  ///
  /// In en, this message translates to:
  /// **'About {minutes, plural, =1{1 minute} other{{minutes} minutes}}, at your pace in your last Drills'**
  String estimatedTime(int minutes);

  /// No description provided for @ratingBasis.
  ///
  /// In en, this message translates to:
  /// **'Based on your puzzle rating, {rating}'**
  String ratingBasis(int rating);

  /// No description provided for @puzzlesOfAbout.
  ///
  /// In en, this message translates to:
  /// **'Puzzles rated about {rating}'**
  String puzzlesOfAbout(int rating);

  /// No description provided for @puzzlesOfAboutLikeYou.
  ///
  /// In en, this message translates to:
  /// **'Puzzles rated about {rating}, like you'**
  String puzzlesOfAboutLikeYou(int rating);

  /// No description provided for @streak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get streak;

  /// Below or after the number of days of the streak, shown large
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{day in a row} other{days in a row}}'**
  String daysInARow(int count);

  /// No description provided for @bestStreakDays.
  ///
  /// In en, this message translates to:
  /// **'Your best streak: {count, plural, =1{1 day} other{{count} days}}'**
  String bestStreakDays(int count);

  /// No description provided for @bestStreakLabel.
  ///
  /// In en, this message translates to:
  /// **'best streak'**
  String get bestStreakLabel;

  /// No description provided for @daysWithDrills.
  ///
  /// In en, this message translates to:
  /// **'days with Drills'**
  String get daysWithDrills;

  /// No description provided for @playTodayToReach.
  ///
  /// In en, this message translates to:
  /// **'Play a Drill today to reach {count, plural, =1{1 day} other{{count} days}}'**
  String playTodayToReach(int count);

  /// No description provided for @playTodayToStart.
  ///
  /// In en, this message translates to:
  /// **'Play a Drill today to start a streak'**
  String get playTodayToStart;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// Legend of the activity calendar, before its colors from fewer to more puzzles
  ///
  /// In en, this message translates to:
  /// **'Fewer'**
  String get fewerPuzzles;

  /// Legend of the activity calendar, after its colors from fewer to more puzzles
  ///
  /// In en, this message translates to:
  /// **'More puzzles'**
  String get morePuzzles;

  /// No description provided for @lastDrills.
  ///
  /// In en, this message translates to:
  /// **'Last Drills'**
  String get lastDrills;

  /// No description provided for @seeHistory.
  ///
  /// In en, this message translates to:
  /// **'See history'**
  String get seeHistory;

  /// No description provided for @toWorkOn.
  ///
  /// In en, this message translates to:
  /// **'To work on'**
  String get toWorkOn;

  /// No description provided for @toWorkOnHint.
  ///
  /// In en, this message translates to:
  /// **'The themes you fail the most in your last 10 Drills'**
  String get toWorkOnHint;

  /// No description provided for @failedOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{failures} of {total} failed'**
  String failedOfTotal(int failures, int total);

  /// No description provided for @recentThemes.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recentThemes;

  /// No description provided for @allThemes.
  ///
  /// In en, this message translates to:
  /// **'All themes'**
  String get allThemes;

  /// No description provided for @giveUp.
  ///
  /// In en, this message translates to:
  /// **'Give up'**
  String get giveUp;

  /// No description provided for @previousMove.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previousMove;

  /// No description provided for @endDrill.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get endDrill;

  /// No description provided for @endDrillConfirmation.
  ///
  /// In en, this message translates to:
  /// **'End the Drill now?'**
  String get endDrillConfirmation;

  /// No description provided for @endPartialDrillWarning.
  ///
  /// In en, this message translates to:
  /// **'You have done {done} of {total} {total, plural, =1{puzzle} other{puzzles}}. The Drill will be left incomplete and you won\'t be able to resume it.'**
  String endPartialDrillWarning(int done, int total);

  /// No description provided for @endEmptyDrillWarning.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t done any puzzle yet: the Drill will be discarded.'**
  String get endEmptyDrillWarning;

  /// No description provided for @leaveDrillHint.
  ///
  /// In en, this message translates to:
  /// **'If you leave with the back arrow, you can resume it later.'**
  String get leaveDrillHint;

  /// No description provided for @summaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Drill summary'**
  String get summaryTitle;

  /// No description provided for @nbPuzzles.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 puzzle} other{{count} puzzles}}'**
  String nbPuzzles(int count);

  /// No description provided for @partial.
  ///
  /// In en, this message translates to:
  /// **'Incomplete'**
  String get partial;

  /// No description provided for @successes.
  ///
  /// In en, this message translates to:
  /// **'Successes'**
  String get successes;

  /// No description provided for @nbSolvedOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{solved} of {total} solved'**
  String nbSolvedOfTotal(int solved, int total);

  /// No description provided for @betterThanExpected.
  ///
  /// In en, this message translates to:
  /// **'Better than expected'**
  String get betterThanExpected;

  /// No description provided for @worseThanExpected.
  ///
  /// In en, this message translates to:
  /// **'Worse than expected'**
  String get worseThanExpected;

  /// No description provided for @asExpected.
  ///
  /// In en, this message translates to:
  /// **'As expected'**
  String get asExpected;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @totalTime.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalTime;

  /// No description provided for @averageTime.
  ///
  /// In en, this message translates to:
  /// **'Per puzzle'**
  String get averageTime;

  /// No description provided for @performance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get performance;

  /// No description provided for @unreliable.
  ///
  /// In en, this message translates to:
  /// **'Unreliable'**
  String get unreliable;

  /// No description provided for @weakestThemes.
  ///
  /// In en, this message translates to:
  /// **'Weakest themes'**
  String get weakestThemes;

  /// No description provided for @weakestThemesHint.
  ///
  /// In en, this message translates to:
  /// **'Tap one to set up a Drill on that theme'**
  String get weakestThemesHint;

  /// No description provided for @train.
  ///
  /// In en, this message translates to:
  /// **'Train'**
  String get train;

  /// Title of the list of the puzzles of a theme in the Drill summary
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The puzzle} other{All {count} puzzles}}'**
  String themePuzzles(int count);

  /// No description provided for @unrated.
  ///
  /// In en, this message translates to:
  /// **'unrated'**
  String get unrated;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'pending'**
  String get pending;

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backToHome;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Drill History'**
  String get historyTitle;

  /// No description provided for @emptyHistory.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t finished any Drill yet.'**
  String get emptyHistory;

  /// No description provided for @deleteDrillsConfirmation.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete this Drill from the history?} other{Delete these {count} Drills from the history?}}'**
  String deleteDrillsConfirmation(int count);

  /// No description provided for @nbSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String nbSelected(int count);

  /// No description provided for @analyzeDrills.
  ///
  /// In en, this message translates to:
  /// **'Analyze'**
  String get analyzeDrills;

  /// No description provided for @deleteDrills.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteDrills;

  /// No description provided for @selectSameDrillsHint.
  ///
  /// In en, this message translates to:
  /// **'Select other Drills of the same theme and difficulty to analyze them together.'**
  String get selectSameDrillsHint;

  /// No description provided for @mixedDrillsHint.
  ///
  /// In en, this message translates to:
  /// **'Only Drills of the same theme and difficulty are analyzed together.'**
  String get mixedDrillsHint;

  /// No description provided for @groupSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Summary of 1 Drill} other{Summary of {count} Drills}}'**
  String groupSummaryTitle(int count);

  /// No description provided for @historyMenu.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get historyMenu;

  /// No description provided for @exportHistory.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportHistory;

  /// No description provided for @importHistory.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importHistory;

  /// No description provided for @historyExported.
  ///
  /// In en, this message translates to:
  /// **'History exported.'**
  String get historyExported;

  /// No description provided for @couldNotExportHistory.
  ///
  /// In en, this message translates to:
  /// **'Could not export the history.'**
  String get couldNotExportHistory;

  /// No description provided for @couldNotImportHistory.
  ///
  /// In en, this message translates to:
  /// **'Could not import the history.'**
  String get couldNotImportHistory;

  /// No description provided for @invalidHistoryFile.
  ///
  /// In en, this message translates to:
  /// **'Not a valid Drill History file.'**
  String get invalidHistoryFile;

  /// No description provided for @drillsImported.
  ///
  /// In en, this message translates to:
  /// **'{added, plural, =0{No Drill added} =1{1 Drill added} other{{added} Drills added}}.'**
  String drillsImported(int added);

  /// No description provided for @drillsImportedSomeInHistory.
  ///
  /// In en, this message translates to:
  /// **'{added, plural, =0{No Drill added} =1{1 Drill added} other{{added} Drills added}}; {existing, plural, =1{1 was already in the history} other{{existing} were already in the history}}.'**
  String drillsImportedSomeInHistory(int added, int existing);

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @points.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get points;

  /// No description provided for @nbOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total}'**
  String nbOfTotal(int count, int total);

  /// After the puzzles played of an incomplete Drill, its number of puzzles
  ///
  /// In en, this message translates to:
  /// **'of {total}'**
  String ofTotal(int total);

  /// No description provided for @expectedPercent.
  ///
  /// In en, this message translates to:
  /// **'expected {percent} %'**
  String expectedPercent(int percent);

  /// No description provided for @nbOfTotalExpectedPercent.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total}, expected {percent} %'**
  String nbOfTotalExpectedPercent(int count, int total, int percent);

  /// No description provided for @allDays.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allDays;

  /// No description provided for @noChartData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noChartData;

  /// No description provided for @changeSinceLastDay.
  ///
  /// In en, this message translates to:
  /// **'{change} over the previous day'**
  String changeSinceLastDay(String change);

  /// No description provided for @changeSinceLastWeek.
  ///
  /// In en, this message translates to:
  /// **'{change} over the previous week'**
  String changeSinceLastWeek(String change);

  /// No description provided for @changeSinceLastMonth.
  ///
  /// In en, this message translates to:
  /// **'{change} over the previous month'**
  String changeSinceLastMonth(String change);

  /// No description provided for @changeSinceLastThreeMonths.
  ///
  /// In en, this message translates to:
  /// **'{change} over the previous 3 months'**
  String changeSinceLastThreeMonths(String change);

  /// No description provided for @changeSinceLastYear.
  ///
  /// In en, this message translates to:
  /// **'{change} over the previous year'**
  String changeSinceLastYear(String change);

  /// No description provided for @aboveExpected.
  ///
  /// In en, this message translates to:
  /// **'Above expected'**
  String get aboveExpected;

  /// No description provided for @withinExpected.
  ///
  /// In en, this message translates to:
  /// **'Within expected'**
  String get withinExpected;

  /// No description provided for @belowExpected.
  ///
  /// In en, this message translates to:
  /// **'Below expected'**
  String get belowExpected;

  /// No description provided for @byDay.
  ///
  /// In en, this message translates to:
  /// **'by day'**
  String get byDay;

  /// No description provided for @byWeek.
  ///
  /// In en, this message translates to:
  /// **'by week'**
  String get byWeek;

  /// No description provided for @byMonth.
  ///
  /// In en, this message translates to:
  /// **'by month'**
  String get byMonth;

  /// No description provided for @weekOf.
  ///
  /// In en, this message translates to:
  /// **'Week of {date}'**
  String weekOf(String date);

  /// No description provided for @nbDrills.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Drill} other{{count} Drills}}'**
  String nbDrills(int count);

  /// Chart range button: the last week
  ///
  /// In en, this message translates to:
  /// **'1W'**
  String get rangeWeek;

  /// Chart range button: the last month
  ///
  /// In en, this message translates to:
  /// **'1M'**
  String get rangeMonth;

  /// Chart range button: the last three months
  ///
  /// In en, this message translates to:
  /// **'3M'**
  String get rangeThreeMonths;

  /// Chart range button: the last year
  ///
  /// In en, this message translates to:
  /// **'1Y'**
  String get rangeYear;

  /// Chart range button of the puzzle rating chart: all time
  ///
  /// In en, this message translates to:
  /// **'ALL'**
  String get rangeAllTime;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'My profile'**
  String get profile;

  /// No description provided for @puzzles.
  ///
  /// In en, this message translates to:
  /// **'Puzzles'**
  String get puzzles;

  /// No description provided for @puzzleRating.
  ///
  /// In en, this message translates to:
  /// **'Puzzle rating'**
  String get puzzleRating;

  /// No description provided for @highestRating.
  ///
  /// In en, this message translates to:
  /// **'Highest'**
  String get highestRating;

  /// No description provided for @lowestRating.
  ///
  /// In en, this message translates to:
  /// **'Lowest'**
  String get lowestRating;

  /// No description provided for @nbPlayed.
  ///
  /// In en, this message translates to:
  /// **'{count} played'**
  String nbPlayed(int count);

  /// No description provided for @highScoreNbRuns.
  ///
  /// In en, this message translates to:
  /// **'highscore · {count, plural, =1{1 run} other{{count} runs}}'**
  String highScoreNbRuns(int count);

  /// No description provided for @highScoreValue.
  ///
  /// In en, this message translates to:
  /// **'highscore {score}'**
  String highScoreValue(int score);

  /// No description provided for @stormChartCaption.
  ///
  /// In en, this message translates to:
  /// **'Best score of each day played · {count, plural, =1{1 day} other{{count} days}}'**
  String stormChartCaption(int count);

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @showClock.
  ///
  /// In en, this message translates to:
  /// **'Show clock'**
  String get showClock;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'Drills is a personal, unofficial version of Lichess Mobile.\nThanks to Lichess for making chess free for everyone.'**
  String get about;

  /// No description provided for @supportLichess.
  ///
  /// In en, this message translates to:
  /// **'Support Lichess'**
  String get supportLichess;
}

class _DrillLocalizationsDelegate extends LocalizationsDelegate<DrillLocalizations> {
  const _DrillLocalizationsDelegate();

  @override
  Future<DrillLocalizations> load(Locale locale) {
    return SynchronousFuture<DrillLocalizations>(lookupDrillLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'es', 'eu'].contains(locale.languageCode);

  @override
  bool shouldReload(_DrillLocalizationsDelegate old) => false;
}

DrillLocalizations lookupDrillLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return DrillLocalizationsEn();
    case 'es': return DrillLocalizationsEs();
    case 'eu': return DrillLocalizationsEu();
  }

  throw FlutterError(
    'DrillLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
