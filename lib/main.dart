import 'package:lichess_mobile/src/binding/binding_fdroid.dart';
import 'package:lichess_mobile/src/bootstrap.dart';

Future<void> main() {
  return bootstrapApp(FdroidLichessBinding.ensureInitialized);
}
