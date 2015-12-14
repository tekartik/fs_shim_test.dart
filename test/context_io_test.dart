@TestOn("vm")
library fs_shim_test.test.context_test;

import 'package:fs_shim_test/test_io.dart';
import 'context_test.dart' as context_test;

class TestScript extends Script {}

String get testScriptPath => getScriptPath(TestScript);
String top = join(dirname(testScriptPath), 'out');
FileSystemTestContext ctx = newIoFileSystemContext(top);

main() {
  defineTests(ctx);
}

void defineTests(FileSystemTestContext ctx) {
  context_test.defineTests(ctx);
  group('context_io', () {
    test('prepare', () async {
      Directory top = await ctx.prepare();

      // check path
      List<String> parts = split(top.path);
      expect(parts, contains("prepare"));

      // check empty
      await top.list().listen((FileSystemEntity fse) {
        fail('$fse not expected');
      }).asFuture();
    });
  });
}
