import 'package:flutter_driver/driver_extension.dart';
import 'package:fs_explorer_app/main.dart' as app;

/// The app with the flutter driver extension on, so a tool can drive it:
/// `flutter run -d linux -t test_driver/app.dart`.
void main() {
  enableFlutterDriverExtension();
  app.main();
}
