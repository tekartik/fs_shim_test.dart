# fs_shim_test.dart

fs_shim test helper for setting up test context

## Usage

### any context (io, browser)

    import 'package:fs_shim_test/test.dart';

    FileSystemTestContext ctx = memoryFileSystemTestContext;

###  io

    import 'package:fs_shim_test/test_io.dart';

    class TestScript extends Script {}

    String get testScriptPath => getScriptPath(TestScript);
    String top = join(dirname(testScriptPath), 'out');
    FileSystemTestContext ctx = newIoFileSystemContext(top);


## Setup

Bleeding edge:

  fs_shim_test:
    git: git://github.com/tekartik/fs_shim_test.dart
