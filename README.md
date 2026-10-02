# FS shim more test

## Test only

See <https://github.com/tekartik/fs_shim.dart>

## Packages

- `packages/fs_idb_sqflite`: fs_shim tests on idb over sqflite (dart, in the
  workspace).
- `packages_flutter/fs_explorer_app`: a Flutter app browsing the fs_shim file
  systems (memory, io, web) as a tree or a list and running scenarios that
  write to them (standalone, not in the dart workspace: resolved by
  `flutter pub get` in its directory).
