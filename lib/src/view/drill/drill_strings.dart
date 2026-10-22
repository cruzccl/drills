/// The UI text of Drills, written directly in Spanish rather than going through the app's
/// translation pipeline. Reused upstream UI keeps its own translations.
abstract class DrillStrings() {
  static const appName = 'Drills';

  static const homeSignInPrompt =
      'Inicia sesión con tu cuenta de Lichess para que tus Drills cuenten en ella.';
  static const nbPuzzlesChoice = 'Número de problemas';
  static const theme = 'Tema';
  static const startDrill = 'Empezar';
  static const couldNotStartDrill = 'No se han podido cargar los problemas.';
  static const resumeDrill = 'Reanudar el Drill';
  static const replaceUnfinishedDrillConfirmation =
      '¿Empezar un Drill nuevo? El que está sin terminar se dará por terminado.';

  static const previousMove = 'Anterior';
  static const endDrill = 'Terminar';
  static const endDrillConfirmation = '¿Terminar el Drill ahora?';

  static const summaryTitle = 'Resumen del Drill';
  static const puzzleUnit = 'problema';
  static const puzzlesUnit = 'problemas';
  static const partial = 'Incompleto';
  static const successes = 'Aciertos';
  static const failures = 'Fallos';
  static const successRate = 'Porcentaje de aciertos';
  static const rating = 'Puntuación';
  static const totalTime = 'Tiempo total';
  static const averageTime = 'Tiempo medio por problema';
  static const performance = 'Rendimiento';
  static const unreliable = 'Poco fiable';
  static const weakestThemes = 'Temas más débiles';
  static const puzzleList = 'Problemas';
  static const unrated = 'sin puntuar';
  static const pending = 'pendiente';
  static const backToHome = 'Volver';

  static const history = 'Historial';
  static const historyTitle = 'Historial de Drills';
  static const emptyHistory = 'Todavía no has terminado ningún Drill.';
  static const deleteDrillConfirmation = '¿Eliminar este Drill del historial?';
  static const casual = 'Sin puntuar';
  static const today = 'Hoy';
  static const yesterday = 'Ayer';
  static const points = 'Puntos';
  static const ofTotal = 'de';
  static const expected = 'Esperado';
  static const average = 'media';
  static const allDrills = 'Todos';
  static const noChartData = 'Sin datos';
  static const sinceLastDrill = 'sobre el anterior';
  static const sinceLastWeek = 'sobre la semana anterior';
  static const sinceLastMonth = 'sobre el mes anterior';
  static const byWeek = 'por semanas';
  static const byMonth = 'por meses';
  static const afterRatedDrills = 'tras cada Drill puntuado';
  static const drillUnit = 'Drill';
  static const drillsUnit = 'Drills';
  static const lastDrills = 'Últimos';
  static const allDrillsCount = 'Todos los Drills';

  static const settingsAccount = 'Cuenta';
  static const settingsPuzzles = 'Problemas';
  static const settingsAppearance = 'Apariencia';

  static const about =
      'Drills es una versión personal y no oficial de Lichess Mobile. '
      'Gracias a Lichess por su aplicación y por hacer el ajedrez libre y gratuito para todos.';
}
