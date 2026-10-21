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

  static const previousMove = 'Anterior';

  static const summaryTitle = 'Resumen del Drill';
  static const nbPuzzles = 'Problemas';
  static const successes = 'Aciertos';
  static const failures = 'Fallos';
  static const successRate = 'Porcentaje de aciertos';
  static const backToHome = 'Volver';

  static const settingsAccount = 'Cuenta';
  static const settingsPuzzles = 'Problemas';
  static const settingsAppearance = 'Apariencia';

  static const about =
      'Drills es una versión personal y no oficial de Lichess Mobile. '
      'Gracias a Lichess por su aplicación y por hacer el ajedrez libre y gratuito para todos.';
}
