# fs_idb_sqflite

Test only package: runs the shared fs_shim suites
([tekartik_fs_test](https://github.com/tekartik/fs_shim.dart/tree/master/fs_test)
`defineFsTests`) on fs_shim's IndexedDB file system (`newFileSystemIdb`) over
[idb_sqflite](https://pub.dev/packages/idb_sqflite) and sqflite_common_ffi,
the setup a Flutter app gets with `newFileSystemIdb(getIdbFactorySqflite(...))`.
No library code, nothing to depend on.

## Runners

| File | File system |
|---|---|
| `test/fs_idb_sqflite_test.dart` | sqlite database files, page sizes default, none, 2 and 1024 |
| `test/fs_idb_sqflite_sandbox_test.dart` | the same in a `/sandbox` folder |
| `test/fs_idb_sqflite_memory_test.dart` | `:memory:` sqlite databases, the 4 page sizes |
| `test/fs_idb_sqflite_memory_sandbox_test.dart` | `:memory:`, two sandboxes |

```sh
dart test
```

Dart VM only. The databases go in `.dart_tool/sqflite_common_ffi/databases`;
on Linux sqflite_common_ffi needs `libsqlite3` (`repo_support` installs it on
CI). The runners share database names: keep `concurrency: 1`
(`dart_test.yaml`).

The suites check the fs_shim 2.7.1 fixes (write mode, truncate, sink done,
sandbox `..`, link loops): with fs_shim 2.7.0 most of them fail.
