import 'dart:async';
import 'dart:io';
import 'context_io.dart' as fs;

import 'package:fs_shim/fs_io.dart' as fs;

export 'package:fs_shim/utils/io/copy.dart';
export 'package:fs_shim/utils/io/read_write.dart';
export 'package:fs_shim/utils/io/entity.dart';

class FileSystemTestContext {
  final fs.FileSystemTestContextIo _context;
  FileSystemTestContext([String top])
      : _context = fs.newIoFileSystemContext(top);

  /// prepare an empty directory
  Future<Directory> prepare() async =>
      fs.unwrapIoDirectory(await _context.prepare());
}
