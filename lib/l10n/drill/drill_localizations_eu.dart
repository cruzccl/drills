// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'drill_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Basque (`eu`).
class DrillLocalizationsEu extends DrillLocalizations {
  DrillLocalizationsEu([String locale = 'eu']) : super(locale);

  @override
  String get signedOutNotice => 'Saioa hasi gabe, Drillak ez dira Lichesseko inongo kontutan kontatzen, ezta historikoan gordetzen ere. Hasi saioa zure kontuan kontatzeko.';

  @override
  String get nbPuzzlesChoice => 'Ariketa kopurua';

  @override
  String get theme => 'Gaia';

  @override
  String get startDrill => 'Hasi';

  @override
  String get warmUpWithStorm => 'Berotu Puzzle Stormekin';

  @override
  String get couldNotStartDrill => 'Ezin izan dira ariketak kargatu.';

  @override
  String get resumeDrill => 'Jarraitu Drillarekin';

  @override
  String get replaceUnfinishedDrillConfirmation => 'Drill berri bat hasi? Amaitu gabekoa amaitutzat emango da.';

  @override
  String get nextDrill => 'Zure hurrengo Drilla';

  @override
  String get nbPuzzlesTile => 'Ariketak';

  @override
  String get difficulty => 'Zailtasuna';

  @override
  String get sameAsLast => 'Azkenaren berdina';

  @override
  String get toWorkOnTag => 'indartzeko';

  @override
  String lastNbPuzzles(int count) {
    return 'Azkena: $count';
  }

  @override
  String get lastOneTag => 'azkena';

  @override
  String get done => 'Eginda';

  @override
  String get onePuzzleLess => 'Ariketa bat gutxiago';

  @override
  String get onePuzzleMore => 'Ariketa bat gehiago';

  @override
  String puzzlesLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ariketa',
    );
    return '$_temp0';
  }

  @override
  String estimatedTime(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutu inguru',
      one: 'Minutu bat inguru',
    );
    return '$_temp0, zure azken Drilletako erritmoan';
  }

  @override
  String ratingBasis(int rating) {
    return 'Zure ariketen puntuazioaren arabera, $rating';
  }

  @override
  String puzzlesOfAbout(int rating) {
    return '$rating inguruko ariketak';
  }

  @override
  String puzzlesOfAboutLikeYou(int rating) {
    return '$rating inguruko ariketak, zu bezala';
  }

  @override
  String get streak => 'Bolada';

  @override
  String daysInARow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'egun jarraian',
    );
    return '$_temp0';
  }

  @override
  String bestStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count egun',
      one: 'egun 1',
    );
    return 'Zure bolada onena: $_temp0';
  }

  @override
  String get bestStreakLabel => 'bolada onena';

  @override
  String get daysWithDrills => 'egun Drillekin';

  @override
  String playTodayToReach(int count) {
    return 'Egin Drill bat gaur $count egunera iristeko';
  }

  @override
  String get playTodayToStart => 'Egin Drill bat gaur bolada bat hasteko';

  @override
  String get progress => 'Aurrerapena';

  @override
  String get fewerPuzzles => 'Gutxiago';

  @override
  String get morePuzzles => 'Ariketa gehiago';

  @override
  String get lastDrills => 'Azken Drillak';

  @override
  String get seeHistory => 'Ikusi historikoa';

  @override
  String get toWorkOn => 'Indartzeko';

  @override
  String get toWorkOnHint => 'Zure azken 10 Drilletan gehien huts egiten dituzun gaiak';

  @override
  String failedOfTotal(int failures, int total) {
    return '$failures/$total huts eginda';
  }

  @override
  String get recentThemes => 'Azkenak';

  @override
  String get allThemes => 'Gai guztiak';

  @override
  String get giveUp => 'Amore eman';

  @override
  String get previousMove => 'Aurrekoa';

  @override
  String get endDrill => 'Amaitu';

  @override
  String get endDrillConfirmation => 'Drilla orain amaitu?';

  @override
  String endPartialDrillWarning(int done, int total) {
    return '$total ariketatik $done egin dituzu. Drilla osatu gabe geratuko da eta ezingo duzu berriro jarraitu.';
  }

  @override
  String get endEmptyDrillWarning => 'Oraindik ez duzu ariketarik egin: Drilla baztertu egingo da.';

  @override
  String get leaveDrillHint => 'Atzera geziarekin irteten bazara, geroago jarraitu ahal izango duzu.';

  @override
  String get summaryTitle => 'Drillaren laburpena';

  @override
  String nbPuzzles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ariketa',
      one: 'Ariketa 1',
    );
    return '$_temp0';
  }

  @override
  String get partial => 'Osatu gabea';

  @override
  String get successes => 'Asmatutakoak';

  @override
  String nbSolvedOfTotal(int solved, int total) {
    return '$solved/$total ebatzita';
  }

  @override
  String get betterThanExpected => 'Espero baino hobeto';

  @override
  String get worseThanExpected => 'Espero baino okerrago';

  @override
  String get asExpected => 'Espero bezala';

  @override
  String get time => 'Denbora';

  @override
  String get totalTime => 'Guztira';

  @override
  String get averageTime => 'Ariketako';

  @override
  String get performance => 'Errendimendua';

  @override
  String get unreliable => 'Ez oso fidagarria';

  @override
  String get weakestThemes => 'Gai ahulenak';

  @override
  String get weakestThemesHint => 'Sakatu bat gai horretako Drill bat prestatzeko';

  @override
  String get train => 'Entrenatu';

  @override
  String themePuzzles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ariketa guztiak',
      one: 'Ariketa',
    );
    return '$_temp0';
  }

  @override
  String get unrated => 'puntuatu gabe';

  @override
  String get pending => 'zain';

  @override
  String get backToHome => 'Itzuli';

  @override
  String get historyTitle => 'Drillen historikoa';

  @override
  String get emptyHistory => 'Oraindik ez duzu Drillik amaitu.';

  @override
  String deleteDrillsConfirmation(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Drill hauek historikotik ezabatu?',
      one: 'Drill hau historikotik ezabatu?',
    );
    return '$_temp0';
  }

  @override
  String nbSelected(int count) {
    return '$count hautatuta';
  }

  @override
  String get analyzeDrills => 'Aztertu';

  @override
  String get deleteDrills => 'Ezabatu';

  @override
  String get selectSameDrillsHint => 'Hautatu gai eta zailtasun bereko beste Drill batzuk elkarrekin aztertzeko.';

  @override
  String get mixedDrillsHint => 'Gai eta zailtasun bereko Drillak bakarrik aztertzen dira elkarrekin.';

  @override
  String groupSummaryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Drillen laburpena',
      one: 'Drill baten laburpena',
    );
    return '$_temp0';
  }

  @override
  String get analyzeByDates => 'Datan arabera aztertu';

  @override
  String get chooseDates => 'Datak aukeratu';

  @override
  String get groupChoicesHint => 'Gai eta zailtasun bereko bi Drill gutxienez aztertzen dira elkarrekin.';

  @override
  String get noDrillsInRange => 'Ez dago Drillik egun hauetan.';

  @override
  String get historyMenu => 'Aukera gehiago';

  @override
  String get exportHistory => 'Esportatu';

  @override
  String get importHistory => 'Inportatu';

  @override
  String get historyExported => 'Historikoa esportatu da.';

  @override
  String get couldNotExportHistory => 'Ezin izan da historikoa esportatu.';

  @override
  String get couldNotImportHistory => 'Ezin izan da historikoa inportatu.';

  @override
  String get invalidHistoryFile => 'Ez da Drillen historikoaren fitxategi baliozkoa.';

  @override
  String drillsImported(int added) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added Drill gehitu dira',
      one: 'Drill 1 gehitu da',
      zero: 'Ez da Drillik gehitu',
    );
    return '$_temp0.';
  }

  @override
  String drillsImportedSomeInHistory(int added, int existing) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added Drill gehitu dira',
      one: 'Drill 1 gehitu da',
      zero: 'Ez da Drillik gehitu',
    );
    String _temp1 = intl.Intl.pluralLogic(
      existing,
      locale: localeName,
      other: '$existing historikoan zeuden jada',
      one: '1 historikoan zegoen jada',
    );
    return '$_temp0; $_temp1.';
  }

  @override
  String get today => 'Gaur';

  @override
  String get yesterday => 'Atzo';

  @override
  String get points => 'Puntuak';

  @override
  String nbOfTotal(int count, int total) {
    return '$count/$total';
  }

  @override
  String ofTotal(int total) {
    return 'guztira $total';
  }

  @override
  String expectedPercent(int percent) {
    return 'espero zena $percent %';
  }

  @override
  String nbOfTotalExpectedPercent(int count, int total, int percent) {
    return '$count/$total, espero zena $percent %';
  }

  @override
  String get allDays => 'Dena';

  @override
  String get noChartData => 'Daturik ez';

  @override
  String changeSinceLastDay(String change) {
    return '$change aurreko egunarekiko';
  }

  @override
  String changeSinceLastWeek(String change) {
    return '$change aurreko astearekiko';
  }

  @override
  String changeSinceLastMonth(String change) {
    return '$change aurreko hilabetearekiko';
  }

  @override
  String changeSinceLastThreeMonths(String change) {
    return '$change aurreko 3 hilabeteekiko';
  }

  @override
  String changeSinceLastYear(String change) {
    return '$change aurreko urtearekiko';
  }

  @override
  String get aboveExpected => 'Espero baino gorago';

  @override
  String get withinExpected => 'Espero bezala';

  @override
  String get belowExpected => 'Espero baino beherago';

  @override
  String get byDay => 'egunka';

  @override
  String get byWeek => 'asteka';

  @override
  String get byMonth => 'hilabeteka';

  @override
  String weekOf(String date) {
    return 'Astea: $date';
  }

  @override
  String nbDrills(int count) {
    return '$count Drill';
  }

  @override
  String get rangeWeek => '1A';

  @override
  String get rangeMonth => '1H';

  @override
  String get rangeThreeMonths => '3H';

  @override
  String get rangeYear => '1U';

  @override
  String get rangeAllTime => 'DENA';

  @override
  String get profile => 'Nire profila';

  @override
  String get puzzles => 'Ariketak';

  @override
  String get puzzleRating => 'Ariketen puntuazioa';

  @override
  String get highestRating => 'Altuena';

  @override
  String get lowestRating => 'Baxuena';

  @override
  String nbPlayed(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString jokatuta';
  }

  @override
  String highScoreNbRuns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saiakera',
      one: 'saiakera 1',
    );
    return 'errekorra · $_temp0';
  }

  @override
  String highScoreValue(int score) {
    return 'errekorra $score';
  }

  @override
  String stormChartCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count egun',
      one: 'egun 1',
    );
    return 'Jokatutako egun bakoitzeko puntuazio onena · $_temp0';
  }

  @override
  String get settingsAccount => 'Kontua';

  @override
  String get settingsAppearance => 'Itxura';

  @override
  String get showClock => 'Erakutsi erlojua';

  @override
  String get about => 'Drills Lichess Mobileren bertsio pertsonal eta ez-ofiziala da.\nEskerrik asko Lichessi xakea guztiontzat libre eta doan egiteagatik.';

  @override
  String get supportLichess => 'Lagundu Lichessi';
}
