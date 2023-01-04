import 'package:dev_test/package.dart';
import 'package:path/path.dart';

var topDir = join('..', 'packages');

Future<void> main() async {
  for (var dir in [
    'fs_idb_sqflite',
  ]) {
    var path = join(topDir, dir);
    // concurrent test are not supported
    await packageRunCi(path);
  }
}
