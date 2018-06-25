library fs_shim.test.test_common_io;

// basically same as the io runner but with extra output
export 'context.dart';
import 'package:path/path.dart';
import 'package:fs_shim/fs_io.dart';
import 'context.dart';
import 'package:platform_context/context.dart';
import 'package:platform_context/context_io.dart';

FileSystemTestContextIo newIoFileSystemContext([String top]) {
  return new FileSystemTestContextIo()..top = top ?? join('tmp', 'test');
}

class FileSystemTestContextIo extends FileSystemTestContext {
  final PlatformContext platform = ioPlatformContext;
  final FileSystem fs = fileSystemIo;
  String top;
  String get outPath => join(top, super.outPath);
}
