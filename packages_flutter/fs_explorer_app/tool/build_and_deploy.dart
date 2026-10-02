import 'build_and_serve.dart';

/// Builds the web app and publishes it to https://demo_fs_explorer.surge.sh
/// (needs the surge cli, logged in).
Future<void> main() async {
  await webAppBuilder.buildAndDeploy();
}
