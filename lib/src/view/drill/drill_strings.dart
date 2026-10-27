/// The UI text of Drills, written directly in Spanish rather than going through the app's
/// translation pipeline. Reused upstream UI keeps its own translations.
abstract class DrillStrings() {
  static const appName = 'Drills';

  static const signedOutNotice =
      'Sin sesión, los Drills no cuentan en ninguna cuenta de Lichess ni se guardan en el '
      'historial. Inicia sesión para que cuenten en la tuya.';
  static const nbPuzzlesChoice = 'Número de problemas';
  static const theme = 'Tema';
  static const startDrill = 'Empezar';
  static const warmUpWithStorm = 'Calentar con Puzzle Storm';
  static const couldNotStartDrill = 'No se han podido cargar los problemas.';
  static const resumeDrill = 'Reanudar el Drill';
  static const replaceUnfinishedDrillConfirmation =
      '¿Empezar un Drill nuevo? El que está sin terminar se dará por terminado.';
  static const nextDrill = 'Tu próximo Drill';
  static const nbPuzzlesTile = 'Problemas';
  static const difficulty = 'Dificultad';
  static const sameAsLast = 'Como el último';
  static const toWorkOnTag = 'para reforzar';
  static const lastOne = 'El último';
  static const lastOneTag = 'el último';
  static const done = 'Hecho';
  static const onePuzzleLess = 'Un problema menos';
  static const onePuzzleMore = 'Un problema más';
  static const ratingBasis = 'Según tu valoración de problemas';
  static const puzzlesOfAbout = 'Problemas de unos';
  static const likeYou = 'como tú';
  static const approximately = 'Unos';
  static const minuteUnit = 'minuto';
  static const minutesUnit = 'minutos';
  static const atYourPace = 'a tu ritmo de los últimos Drills';

  static const streak = 'Racha';
  static const dayInARow = 'día seguido';
  static const daysInARow = 'días seguidos';
  static const bestStreak = 'Tu mejor racha';
  static const bestStreakLabel = 'mejor racha';
  static const daysWithDrills = 'días con Drills';
  static const playTodayToReach = 'Haz un Drill hoy para llegar a';
  static const playTodayToStart = 'Haz un Drill hoy para empezar una racha';
  static const progress = 'Progreso';
  static const fewerPuzzles = 'Menos';
  static const morePuzzles = 'Más problemas';
  static const lastDrills = 'Últimos Drills';
  static const seeHistory = 'Ver historial';

  static const toWorkOn = 'Para reforzar';
  static const toWorkOnHint = 'Los temas que más fallas en tus últimos 10 Drills';
  static const failed = 'fallados';
  static const recentThemes = 'Recientes';
  static const allThemes = 'Todos los temas';

  static const giveUp = 'Rendirse';
  static const previousMove = 'Anterior';
  static const endDrill = 'Terminar';
  static const endDrillConfirmation = '¿Terminar el Drill ahora?';
  static const youHaveDone = 'Has hecho';
  static const endPartialDrillWarning = 'El Drill quedará incompleto y no podrás retomarlo.';
  static const endEmptyDrillWarning = 'Aún no has hecho ningún problema: el Drill se descartará.';
  static const leaveDrillHint = 'Si sales con la flecha atrás, podrás retomarlo más tarde.';

  static const summaryTitle = 'Resumen del Drill';
  static const puzzleUnit = 'problema';
  static const puzzlesUnit = 'problemas';
  static const partial = 'Incompleto';
  static const successes = 'Aciertos';
  static const solvedUnit = 'resuelto';
  static const solvedUnitPlural = 'resueltos';
  static const betterThanExpected = 'Mejor de lo esperado';
  static const worseThanExpected = 'Peor de lo esperado';
  static const asExpected = 'Como se esperaba';
  static const time = 'Tiempo';
  static const totalTime = 'Total';
  static const averageTime = 'Por problema';
  static const performance = 'Rendimiento';
  static const unreliable = 'Poco fiable';
  static const weakestThemes = 'Temas más débiles';
  static const weakestThemesHint = 'Toca uno para preparar un Drill de ese tema';
  static const train = 'Entrenar';
  static const onePuzzle = 'El problema';
  static const allPuzzles = 'Los';
  static const unrated = 'sin puntuar';
  static const pending = 'pendiente';
  static const backToHome = 'Volver';

  static const history = 'Historial';
  static const historyTitle = 'Historial de Drills';
  static const emptyHistory = 'Todavía no has terminado ningún Drill.';
  static const deleteDrillConfirmation = '¿Eliminar este Drill del historial?';
  static const historyMenu = 'Más opciones';
  static const exportHistory = 'Exportar';
  static const importHistory = 'Importar';
  static const historyExported = 'Historial exportado.';
  static const couldNotExportHistory = 'No se ha podido exportar el historial.';
  static const couldNotImportHistory = 'No se ha podido importar el historial.';
  static const invalidHistoryFile = 'No es un archivo de historial de Drills válido.';
  static const noDrillAdded = 'Ningún Drill añadido';
  static const drillAdded = 'Drill añadido';
  static const drillsAdded = 'Drills añadidos';
  static const alreadyInHistory = 'ya estaba en el historial';
  static const alreadyInHistoryPlural = 'ya estaban en el historial';

  static const today = 'Hoy';
  static const yesterday = 'Ayer';
  static const points = 'Puntos';
  static const ofTotal = 'de';
  static const average = 'media';
  static const allDays = 'Todo';
  static const noChartData = 'Sin datos';
  static const expected = 'esperado';
  static const sinceLastWeek = 'sobre la semana anterior';
  static const sinceLastMonth = 'sobre el mes anterior';
  static const sinceLastThreeMonths = 'sobre los 3 meses anteriores';
  static const sinceLastYear = 'sobre el año anterior';
  static const aboveExpected = 'Por encima de lo esperado';
  static const withinExpected = 'Dentro de lo esperado';
  static const belowExpected = 'Por debajo de lo esperado';
  static const byDay = 'por días';
  static const byWeek = 'por semanas';
  static const weekOf = 'Semana del';
  static const byMonth = 'por meses';
  static const drillUnit = 'Drill';
  static const drillsUnit = 'Drills';

  static const profile = 'Mi perfil';
  static const puzzles = 'Problemas';
  static const puzzleRating = 'Valoración de problemas';
  static const highestRating = 'Máxima';
  static const lowestRating = 'Mínima';
  static const played = 'jugados';
  static const highScore = 'récord';
  static const run = 'ronda';
  static const runs = 'rondas';
  static const stormChartCaption = 'Mejor puntuación de cada día jugado';
  static const sinceLastDay = 'sobre el día anterior';
  static const dayUnit = 'día';
  static const daysUnit = 'días';

  static const settingsAccount = 'Cuenta';
  static const settingsDrills = 'Drills';
  static const settingsAppearance = 'Apariencia';
  static const showClock = 'Mostrar reloj';

  static const about =
      'Drills es una versión personal y no oficial de Lichess Mobile.\n'
      'Gracias a Lichess por hacer el ajedrez libre y gratuito para todos.';
  static const supportLichess = 'Apoya a Lichess';
}
