@TestOn("vm")
library fs_shim_test.test.context_test;

import 'package:dev_test/test.dart';
import 'package:fs_shim_test/context_io.dart';
import 'context_test.dart' as context_test;
import 'dart:mirrors';
import 'package:path/path.dart';
import 'package:fs_shim/fs_io.dart';

String getScriptPath(Type type) =>
    (reflectClass(type).owner as LibraryMirror).uri.toFilePath();

abstract class TestScript {
  String get path => getScriptPath(this.runtimeType);
}

String get testScriptPath => getScriptPath(TestScript);
String top = join(dirname(testScriptPath), 'out');
FileSystemTestContext ctx = newIoFileSystemContext(top);

main() {
  defineTests(ctx);
  group('raw_io', () {
    test('dir', () async {
      Directory top = await ctx.prepare() as Directory;
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
  context_test.defineTests(ctx);
  group('context_io', () {
    test('prepare', () async {
      Directory top = await ctx.prepare() as Directory;

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
