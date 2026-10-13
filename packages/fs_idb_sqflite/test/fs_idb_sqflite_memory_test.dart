@TestOn('vm')
// Copyright (c) 2015, Alexandre Roux. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.
library;

import 'package:test/test.dart';
import 'package:fs_shim/fs_idb.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tekartik_fs_test/fs_test.dart';

import 'fs_idb_sqflite_test.dart';

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
