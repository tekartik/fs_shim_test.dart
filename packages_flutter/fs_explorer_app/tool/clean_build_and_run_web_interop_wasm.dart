import 'package:path/path.dart';
import 'package:process_run/shell.dart';

import 'dhttpd.dart';

/// A clean wasm build of the web app, served on http://localhost:8080 with
/// the cross origin headers wasm needs.
Future<void> main() async {
  await checkOrPubActivateDhttpd();
  var shell = Shell();
  await shell.run('''
      flutter clean
      flutter build web --wasm''');
  shell = shell.cd(join('build', 'web'));
  // ignore: avoid_print
  print('http://localhost:8080');

  await shell.run(
    'dart pub global run dhttpd:dhttpd . --headers=Cross-Origin-Embedder-Policy=credentialless;Cross-Origin-Opener-Policy=same-origin',
  );
}
