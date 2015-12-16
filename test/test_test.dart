library fs_shim_test.test.context_test;

import 'package:fs_shim_test/test.dart';

FileSystemTestContext ctx = memoryFileSystemTestContext;
FileSystem get fs => ctx.fs;
main() {
  defineTests(ctx);
}

void defineTests(FileSystemTestContext ctx_) {
  ctx = ctx;
  group('context', () {
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
