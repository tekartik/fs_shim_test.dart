@TestOn('vm')
// Copyright (c) 2015, Alexandre Roux. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.
library;

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tekartik_fs_test/fs_test.dart';
import 'package:test/test.dart';

import 'fs_idb_sqflite_test.dart';

void main() {
  sqfliteFfiInit();
  var testContext = FileSystemTestContextIdbSqfliteMemory();
  // debugIdbShowLogs = devWarning(true);
  group('idb_sqflite_memory_sandbox', () {
    defineFsTests(testContext.sandbox(path: '/sandbox'));
    defineFsTests(
      testContext.sandbox(path: 'other_sandbox').sandbox(path: '/sub'),
    );
  });
}
