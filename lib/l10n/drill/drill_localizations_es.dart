// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'drill_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class DrillLocalizationsEs extends DrillLocalizations {
  DrillLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get signedOutNotice => 'Sin sesión, los Drills no cuentan en ninguna cuenta de Lichess ni se guardan en el historial. Inicia sesión para que cuenten en la tuya.';

  @override
  String get nbPuzzlesChoice => 'Número de problemas';

  @override
  String get theme => 'Tema';

  @override
  String get startDrill => 'Empezar';

  @override
  String get warmUpWithStorm => 'Calentar con Puzzle Storm';

  @override
  String get couldNotStartDrill => 'No se han podido cargar los problemas.';

  @override
  String get resumeDrill => 'Reanudar el Drill';

  @override
  String get replaceUnfinishedDrillConfirmation => '¿Empezar un Drill nuevo? El que está sin terminar se dará por terminado.';

  @override
  String get nextDrill => 'Tu próximo Drill';

  @override
  String get nbPuzzlesTile => 'Problemas';

  @override
  String get difficulty => 'Dificultad';

  @override
  String get sameAsLast => 'Como el último';

  @override
  String get toWorkOnTag => 'para reforzar';

  @override
  String lastNbPuzzles(int count) {
    return 'El último: $count';
  }

  @override
  String get lastOneTag => 'el último';

  @override
  String get done => 'Hecho';

  @override
  String get onePuzzleLess => 'Un problema menos';

  @override
  String get onePuzzleMore => 'Un problema más';

  @override
  String puzzlesLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'problemas',
      one: 'problema',
    );
    return '$_temp0';
  }

  @override
  String estimatedTime(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'minutos',
      one: 'minuto',
    );
    return 'Unos $minutes $_temp0, a tu ritmo de los últimos Drills';
  }

  @override
  String ratingBasis(int rating) {
    return 'Según tu valoración de problemas, $rating';
  }

  @override
  String puzzlesOfAbout(int rating) {
    return 'Problemas de unos $rating';
  }

  @override
  String puzzlesOfAboutLikeYou(int rating) {
    return 'Problemas de unos $rating, como tú';
  }

  @override
  String get streak => 'Racha';

  @override
  String daysInARow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'días seguidos',
      one: 'día seguido',
    );
    return '$_temp0';
  }

  @override
  String bestStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'días',
      one: 'día',
    );
    return 'Tu mejor racha: $count $_temp0';
  }

  @override
  String get bestStreakLabel => 'mejor racha';

  @override
  String get daysWithDrills => 'días con Drills';

  @override
  String playTodayToReach(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'días',
      one: 'día',
    );
    return 'Haz un Drill hoy para llegar a $count $_temp0';
  }

  @override
  String get playTodayToStart => 'Haz un Drill hoy para empezar una racha';

  @override
  String get progress => 'Progreso';

  @override
  String get fewerPuzzles => 'Menos';

  @override
  String get morePuzzles => 'Más problemas';

  @override
  String get lastDrills => 'Últimos Drills';

  @override
  String get seeHistory => 'Ver historial';

  @override
  String get toWorkOn => 'Para reforzar';

  @override
  String get toWorkOnHint => 'Los temas que más fallas en tus últimos 10 Drills';

  @override
  String failedOfTotal(int failures, int total) {
    return 'fallados $failures de $total';
  }

  @override
  String get recentThemes => 'Recientes';

  @override
  String get allThemes => 'Todos los temas';

  @override
  String get giveUp => 'Rendirse';

  @override
  String get previousMove => 'Anterior';

  @override
  String get endDrill => 'Terminar';

  @override
  String get endDrillConfirmation => '¿Terminar el Drill ahora?';

  @override
  String endPartialDrillWarning(int done, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'problemas',
      one: 'problema',
    );
    return 'Has hecho $done de $total $_temp0. El Drill quedará incompleto y no podrás retomarlo.';
  }

  @override
  String get endEmptyDrillWarning => 'Aún no has hecho ningún problema: el Drill se descartará.';

  @override
  String get leaveDrillHint => 'Si sales con la flecha atrás, podrás retomarlo más tarde.';

  @override
  String get summaryTitle => 'Resumen del Drill';

  @override
  String nbPuzzles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'problemas',
      one: 'problema',
    );
    return '$count $_temp0';
  }

  @override
  String get partial => 'Incompleto';

  @override
  String get successes => 'Aciertos';

  @override
  String nbSolvedOfTotal(int solved, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'resueltos',
      one: 'resuelto',
    );
    return '$solved de $total $_temp0';
  }

  @override
  String get betterThanExpected => 'Mejor de lo esperado';

  @override
  String get worseThanExpected => 'Peor de lo esperado';

  @override
  String get asExpected => 'Como se esperaba';

  @override
  String get time => 'Tiempo';

  @override
  String get totalTime => 'Total';

  @override
  String get averageTime => 'Por problema';

  @override
  String get performance => 'Rendimiento';

  @override
  String get unreliable => 'Poco fiable';

  @override
  String get weakestThemes => 'Temas más débiles';

  @override
  String get weakestThemesHint => 'Toca uno para preparar un Drill de ese tema';

  @override
  String get train => 'Entrenar';

  @override
  String themePuzzles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Los $count problemas',
      one: 'El problema',
    );
    return '$_temp0';
  }

  @override
  String get unrated => 'sin puntuar';

  @override
  String get pending => 'pendiente';

  @override
  String get backToHome => 'Volver';

  @override
  String get historyTitle => 'Historial de Drills';

  @override
  String get emptyHistory => 'Todavía no has terminado ningún Drill.';

  @override
  String deleteDrillsConfirmation(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '¿Eliminar estos $count Drills del historial?',
      one: '¿Eliminar este Drill del historial?',
    );
    return '$_temp0';
  }

  @override
  String nbSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seleccionados',
      one: '1 seleccionado',
    );
    return '$_temp0';
  }

  @override
  String get analyzeDrills => 'Analizar';

  @override
  String get deleteDrills => 'Eliminar';

  @override
  String get selectSameDrillsHint => 'Marca otros Drills del mismo tema y dificultad para analizarlos juntos.';

  @override
  String get mixedDrillsHint => 'Solo se analizan juntos Drills del mismo tema y dificultad.';

  @override
  String groupSummaryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Resumen de $count Drills',
      one: 'Resumen de 1 Drill',
    );
    return '$_temp0';
  }

  @override
  String get historyMenu => 'Más opciones';

  @override
  String get exportHistory => 'Exportar';

  @override
  String get importHistory => 'Importar';

  @override
  String get historyExported => 'Historial exportado.';

  @override
  String get couldNotExportHistory => 'No se ha podido exportar el historial.';

  @override
  String get couldNotImportHistory => 'No se ha podido importar el historial.';

  @override
  String get invalidHistoryFile => 'No es un archivo de historial de Drills válido.';

  @override
  String drillsImported(int added) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added Drills añadidos',
      one: '1 Drill añadido',
      zero: 'Ningún Drill añadido',
    );
    return '$_temp0.';
  }

  @override
  String drillsImportedSomeInHistory(int added, int existing) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added Drills añadidos',
      one: '1 Drill añadido',
      zero: 'Ningún Drill añadido',
    );
    String _temp1 = intl.Intl.pluralLogic(
      existing,
      locale: localeName,
      other: '$existing ya estaban en el historial',
      one: '1 ya estaba en el historial',
    );
    return '$_temp0; $_temp1.';
  }

  @override
  String get today => 'Hoy';

  @override
  String get yesterday => 'Ayer';

  @override
  String get points => 'Puntos';

  @override
  String nbOfTotal(int count, int total) {
    return '$count de $total';
  }

  @override
  String ofTotal(int total) {
    return 'de $total';
  }

  @override
  String expectedPercent(int percent) {
    return 'esperado $percent %';
  }

  @override
  String nbOfTotalExpectedPercent(int count, int total, int percent) {
    return '$count de $total, esperado $percent %';
  }

  @override
  String get allDays => 'Todo';

  @override
  String get noChartData => 'Sin datos';

  @override
  String changeSinceLastDay(String change) {
    return '$change sobre el día anterior';
  }

  @override
  String changeSinceLastWeek(String change) {
    return '$change sobre la semana anterior';
  }

  @override
  String changeSinceLastMonth(String change) {
    return '$change sobre el mes anterior';
  }

  @override
  String changeSinceLastThreeMonths(String change) {
    return '$change sobre los 3 meses anteriores';
  }

  @override
  String changeSinceLastYear(String change) {
    return '$change sobre el año anterior';
  }

  @override
  String get aboveExpected => 'Por encima de lo esperado';

  @override
  String get withinExpected => 'Dentro de lo esperado';

  @override
  String get belowExpected => 'Por debajo de lo esperado';

  @override
  String get byDay => 'por días';

  @override
  String get byWeek => 'por semanas';

  @override
  String get byMonth => 'por meses';

  @override
  String weekOf(String date) {
    return 'Semana del $date';
  }

  @override
  String nbDrills(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Drills',
      one: 'Drill',
    );
    return '$count $_temp0';
  }

  @override
  String get rangeWeek => '1S';

  @override
  String get rangeMonth => '1M';

  @override
  String get rangeThreeMonths => '3M';

  @override
  String get rangeYear => '1A';

  @override
  String get rangeAllTime => 'TODO';

  @override
  String get profile => 'Mi perfil';

  @override
  String get puzzles => 'Problemas';

  @override
  String get puzzleRating => 'Valoración de problemas';

  @override
  String get highestRating => 'Máxima';

  @override
  String get lowestRating => 'Mínima';

  @override
  String nbPlayed(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString jugados',
      one: '$countString jugado',
    );
    return '$_temp0';
  }

  @override
  String highScoreNbRuns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'rondas',
      one: 'ronda',
    );
    return 'récord · $count $_temp0';
  }

  @override
  String highScoreValue(int score) {
    return 'récord $score';
  }

  @override
  String stormChartCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'días',
      one: 'día',
    );
    return 'Mejor puntuación de cada día jugado · $count $_temp0';
  }

  @override
  String get settingsAccount => 'Cuenta';

  @override
  String get settingsAppearance => 'Apariencia';

  @override
  String get showClock => 'Mostrar reloj';

  @override
  String get about => 'Drills es una versión personal y no oficial de Lichess Mobile.\nGracias a Lichess por hacer el ajedrez libre y gratuito para todos.';

  @override
  String get supportLichess => 'Apoya a Lichess';
}
