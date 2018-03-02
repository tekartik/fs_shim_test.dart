@TestOn("vm")
library _;

import 'package:dev_test/test.dart';
import 'package:fs_shim/fs_io.dart';
import 'package:fs_shim/utils/copy.dart';
import 'package:fs_shim/utils/entity.dart';
import 'package:fs_shim/utils/read_write.dart';
import 'package:fs_shim_test/context_io.dart';
import 'package:path/path.dart';

FileSystemTestContext ctx = newIoFileSystemContext();

main() {
  group('template', () {
    test('dir', () async {
      Directory top = await ctx.prepare() as Directory;
      //Directory
      Directory dir = new Directory(join(top.path, 'dir'));

      await deleteDirectory(dir);
      expect(await dir.exists(), isFalse);

      File file = childFile(dir, "file") as File;
      await writeString(file, "test");

      await dir.create();
      expect(await dir.exists(), isTrue);
      await deleteDirectory(dir);
      expect(await dir.exists(), isFalse);
      //print(top);
    });

    test('file', () async {
      Directory top = await ctx.prepare() as Directory;
      File file = childFile(top, "file") as File;
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
