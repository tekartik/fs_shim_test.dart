@TestOn('vm')
import 'package:path/path.dart';
import 'package:fs_shim/fs_io.dart';
import 'package:tekartik_fs_test/fs_test.dart';
import 'package:tekartik_fs_test/test_common.dart';

class FileSystemTestContextIo extends FileSystemTestContext {
  @override
  final PlatformContext platform = platformContextIo;

  @override
  FileSystem fs = fileSystemIo; // Needed for initialization (supportsLink)
  FileSystemTestContextIo() {
    basePath = join('.dart_tool', 'tekartik_fs_io', 'test');
  }
}

FileSystemTestContextIo fileSystemTestContextIo = FileSystemTestContextIo();

void main() {
  group('io', () {
    defineTests(fileSystemTestContextIo);
  });
}
