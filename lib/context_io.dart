library fs_shim.test.test_common_io;

// basically same as the io runner but with extra output
export 'context.dart';
import 'package:path/path.dart';
import 'package:fs_shim/fs_io.dart';
import 'context.dart';
import 'package:platform_context/context.dart';
import 'package:platform_context/context_io.dart';

IoFileSystemTestContext newIoFileSystemContext([String top]) {
  return new IoFileSystemTestContext()..top = top ?? join('tmp', 'test');
}

class IoFileSystemTestContext extends FileSystemTestContext {
  final PlatformContext platform = ioPlatformContext;
  final IoFileSystem fs = new IoFileSystem();
  String top;
  String get outPath => join(top, super.outPath);
}
