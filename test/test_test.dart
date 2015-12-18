library fs_shim_test.test.context_test;

import 'package:fs_shim_test/test.dart';

FileSystemTestContext ctx = memoryFileSystemTestContext;
FileSystem get fs => ctx.fs;
main() {
  defineTests(ctx);
}

void defineTests(FileSystemTestContext ctx_) {
  ctx = ctx_;
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

    group('sanity', () {
      Directory top;
      Directory src;
      Directory dst;

      Future _prepare() async {
        top = await ctx.prepare();
        src = childDirectory(top, "src");
        dst = childDirectory(top, "dst");
      }

      test('exclude', () async {
        await _prepare();
        await writeString(childFile(src, "file1"), "test");
        await writeString(childFile(src, "file2"), "test");
        await copyDirectory(src, dst,
            options: new CopyOptions(recursive: true, exclude: ["file1"]));
        expect(await entityExists(childFile(dst, "file1")), isFalse);
        expect(await readString(childFile(dst, "file2")), "test");
      });
    });
  });
}
