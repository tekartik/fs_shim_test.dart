@TestOn('vm')
// Copyright (c) 2015, Alexandre Roux. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library fs_shim.fs_idb_sqflite_test;

import 'package:fs_shim/fs_idb.dart';
import 'package:fs_shim/src/idb/idb_file_system.dart';
import 'package:idb_sqflite/idb_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tekartik_fs_test/fs_test.dart';
import 'package:tekartik_fs_test/test_common.dart';
import 'package:test/test.dart';

final _idbFactory = getIdbFactorySqflite(databaseFactoryFfi);

FileSystem newIdbSqfliteFileSystem([String? name]) {
  return newFileSystemIdb(_idbFactory, name);
}

var _index = 0;

class FileSystemTestContextIdbSqflite
    extends FileSystemTestContextIdbWithOptions {
  @override
  late final IdbFileSystem rawFsIdb = () {
    var fs = newIdbSqfliteFileSystem('test_idb_sqflite_${++_index}.db');

    fs = fs.withIdbOptions(options: options);
    return fs as FileSystemIdb;
  }();

  FileSystemTestContextIdbSqflite({FileSystemIdbOptions? options})
      : super(options: options ?? FileSystemIdbOptions.pageDefault);
}

void main() {
  sqfliteFfiInit();
  // debugIdbShowLogs = devWarning(true);
  group('idb_sqflite', () {
    for (var options in [
      FileSystemIdbOptions.pageDefault,
      FileSystemIdbOptions.noPage,
      const FileSystemIdbOptions(pageSize: 2),
      const FileSystemIdbOptions(pageSize: 1024)
    ]) {
      group('pageSize ${options.pageSize}', () {
        defineFsTests(FileSystemTestContextIdbSqflite(options: options));
      });
    }
  });
}
