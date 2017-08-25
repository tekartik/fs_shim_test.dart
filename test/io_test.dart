@TestOn("vm")
library _;

import 'dart:io';
import 'package:dev_test/test.dart';
import 'package:fs_shim_test/io.dart';
import 'package:path/path.dart';

FileSystemTestContext ctx = new FileSystemTestContext();

main() {
  group('template', () {
    test('dir', () async {
      Directory top = await ctx.prepare();
      //Directory
      Directory dir = new Directory(join(top.path, 'dir'));

      await deleteDirectory(dir);
      expect(await dir.exists(), isFalse);

      File file = childFile(dir, "file");
      await writeString(file, "test");

      await dir.create();
      expect(await dir.exists(), isTrue);
      await deleteDirectory(dir);
      expect(await dir.exists(), isFalse);
      //print(top);
    });

    test('file', () async {
      Directory top = await ctx.prepare();
      File file = childFile(top, "file");
      expect(await file.exists(), isFalse);
      await writeString(file, "test");
      await deleteFile(file);
      expect(await file.exists(), isFalse);

      await deleteFile(file);
      expect(await file.exists(), isFalse);

      //print(top);
    });
  });
}
