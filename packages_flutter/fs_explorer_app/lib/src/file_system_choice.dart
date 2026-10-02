import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fs_shim/fs_idb.dart' show newFileSystemIdb;
import 'package:fs_shim/fs_memory.dart' show newFileSystemMemory;
import 'package:idb_shim/idb_client_memory.dart' show idbFactoryMemory;
import 'package:tekartik_app_flutter_fs/fs.dart';

/// The name of the directory the app keeps its own data in, in every file
/// system: the only place a scenario writes.
const fsExplorerAppDirectoryName = 'fs_explorer_app';

/// The package name, what names the documents directory on linux and
/// windows.
const fsExplorerAppPackageName = 'fs_explorer_app';

/// One file system the app browses and runs scenarios in.
///
/// [appDirectory] is where the app's own data goes: a sub directory of the
/// support directory of the file system, so an io file system is never
/// written outside what the platform gives the app.
class FsChoice {
  /// `memory`, `io`, `web` or `idb_memory`.
  final String id;

  /// What the home screen displays.
  final String name;

  /// A line under it.
  final String description;

  /// The file system itself.
  final FileSystem fileSystem;

  /// Choice [id] of [fileSystem].
  const FsChoice({
    required this.id,
    required this.name,
    required this.description,
    required this.fileSystem,
  });

  /// True for the file system of the platform: the disk on mobile and
  /// desktop, indexeddb in a browser.
  bool get isPlatform => identical(fileSystem, fs);

  /// The directory the app's data goes in, created if needed.
  Future<Directory> appDirectory() async {
    final support = await fileSystem.getApplicationSupportDirectory();
    final directory = fileSystem.directory(
      fileSystem.path.join(support.path, fsExplorerAppDirectoryName),
    );
    await directory.create(recursive: true);
    return directory;
  }

  @override
  String toString() => '$id (${fileSystem.name})';
}

/// The file systems the app offers, built once per app: the memory one keeps
/// what is written in it as long as the app runs.
///
/// - memory: `fs_shim` in memory, gone when the app stops.
/// - io: the disk, on mobile and desktop.
/// - web: indexeddb, in a browser.
/// - idb_memory: the web engine (`fs_shim` over `idb_shim`) on an in memory
///   indexeddb, so the web layout can be looked at without a browser.
List<FsChoice> fsExplorerChoices() => [
  FsChoice(
    id: 'memory',
    name: 'Memory',
    description: 'A scratch file system, gone when the app stops',
    fileSystem: newFileSystemMemory(),
  ),
  if (kIsWeb)
    FsChoice(
      id: 'web',
      name: 'Web',
      description: 'IndexedDB in this browser, kept between reloads',
      fileSystem: fs,
    )
  else
    FsChoice(
      id: 'io',
      name: 'IO',
      description:
          'The disk, through the directories the platform gives the app',
      fileSystem: fs,
    ),
  FsChoice(
    id: 'idb_memory',
    name: 'Idb (memory)',
    description:
        'The web engine over an in memory IndexedDB, '
        'to see the web layout without a browser',
    fileSystem: newFileSystemIdb(idbFactoryMemory),
  ),
];
