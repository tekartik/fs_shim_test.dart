@TestOn('vm')
// Copyright (c) 2015, Alexandre Roux. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.
library;

import 'package:test/test.dart';
import 'package:fs_shim/fs_idb.dart';
import 'package:fs_shim/src/idb/idb_file_system.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tekartik_fs_test/fs_test.dart';
import 'package:tekartik_fs_test/test_common.dart';

import 'fs_idb_sqflite_test.dart';

class FileSystemTestContextIdbSqfliteMemory
    extends FileSystemTestContextIdbWithOptions {
  @override
  late final IdbFileSystem rawFsIdb = () {
    var fs = newIdbSqfliteFileSystem(inMemoryDatabasePath);

    return fs as FileSystemIdb;
  }();

  FileSystemTestContextIdbSqfliteMemory({FileSystemIdbOptions? options})
    : super(options: options ?? FileSystemIdbOptions.pageDefault);
}

void main() {
  sqfliteFfiInit();
  // debugIdbShowLogs = devWarning(true);
  group('idb_sqflite_memory', () {
    for (var options in [
      FileSystemIdbOptions.pageDefault,
      FileSystemIdbOptions.noPage,
      const FileSystemIdbOptions(pageSize: 2),
      const FileSystemIdbOptions(pageSize: 1024),
    ]) {
      group('pageSize ${options.pageSize}', () {
        defineFsTests(FileSystemTestContextIdbSqfliteMemory(options: options));
      });
    }
  });
}
