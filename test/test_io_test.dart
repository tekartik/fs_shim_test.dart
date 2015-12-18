@TestOn("vm")
library fs_shim_test.test.context_test;

import 'package:fs_shim_test/test_io.dart';
import 'test_test.dart' as test_test;

class TestScript extends Script {}

String get testScriptPath => getScriptPath(TestScript);
String top = join(dirname(testScriptPath), 'out');
FileSystemTestContext ctx = newIoFileSystemContext(top);

main() {
  defineTests(ctx);
  group('test_io_raw', () {
    test('dir', () async {
      Directory top = await ctx.prepare();
      //Directory
      Directory dir = new Directory(join(top.path, 'dir'));
      expect(await dir.exists(), isFalse);
      await dir.create();
      expect(await dir.exists(), isTrue);
      //print(top);
    });
  });
}

void defineTests(FileSystemTestContext ctx) {
  group('test_io', () {
    test_test.defineTests(ctx);
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
