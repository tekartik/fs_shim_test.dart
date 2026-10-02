import 'package:festenao_common/fs/file_system_explorer.dart';
import 'package:sembast/sembast.dart' as sembast;
import 'package:sembast/timestamp.dart';

import 'scenario.dart';

/// Creates a text file every tick for 30 ticks — a file every second for
/// 30 seconds in the app.
///
/// Each step makes the directory again if it is gone, so clearing the storage
/// meanwhile only costs the files already written.
class CreateFileEverySecondScenario extends FsScenario {
  /// How many files.
  final int count;

  /// Scenario of [count] files.
  CreateFileEverySecondScenario({this.count = 30});

  @override
  String get id => 'create_file_every_second';

  @override
  String get title => 'A file every second';

  @override
  String get description =>
      'Creates ticks/tick_01.txt, ticks/tick_02.txt… one every second for '
      '$count seconds, each holding the time it was written.';

  @override
  Future<void> run(FsScenarioContext context) async {
    context.log('Creating $count files, one per tick');
    await context.attempt('Creating ticks/', () async {
      await context.explorer.createDirectory('ticks');
      context.action('Created ticks/');
    });
    for (var index = 1; index <= count; index++) {
      final name = 'tick_${index.toString().padLeft(2, '0')}.txt';
      final path = 'ticks/$name';
      await context.attempt('Creating $path', () async {
        if (await context.ensureDirectory('ticks')) {
          context.warn('ticks/ was gone, made it again');
        }
        final content =
            'Tick $index of $count at ${DateTime.now().toIso8601String()}\n';
        final entry = await context.explorer.createFile(path, content: content);
        context.action('Created $path (${entry.size} B)');
      });
      context.changed();
      context.progress(index, count);
      if (index < count && !await context.wait()) {
        return;
      }
    }
    final left = await context.attempt(
      'Counting ticks/',
      () => context.explorer.list('ticks'),
    );
    context.log('${left?.length ?? 0} files in ticks/ at the end');
  }
}

/// Appends a line to one file every tick for 30 ticks, so its size grows in
/// the tree.
class GrowingFileScenario extends FsScenario {
  /// How many lines.
  final int count;

  /// Scenario of [count] lines.
  GrowingFileScenario({this.count = 30});

  @override
  String get id => 'growing_file';

  @override
  String get title => 'A growing file';

  @override
  String get description =>
      'Appends a line to growing/journal.txt every second for $count seconds; '
      'watch its size in the tree.';

  static const _path = 'growing/journal.txt';

  @override
  Future<void> run(FsScenarioContext context) async {
    context.log('Appending $count lines to $_path');
    await context.attempt('Creating growing/', () async {
      await context.explorer.createDirectory('growing');
      context.action('Created growing/');
    });
    for (var index = 1; index <= count; index++) {
      await context.attempt('Appending line $index', () async {
        if (await context.ensureDirectory('growing')) {
          context.warn('growing/ was gone, made it again');
        }
        final explorer = context.explorer;
        final existing = await explorer.entry(_path);
        final previous = existing == null
            ? ''
            : await explorer.readAsString(_path);
        final line = 'Line $index at ${DateTime.now().toIso8601String()}\n';
        await explorer.writeAsString(_path, '$previous$line');
        final entry = await explorer.entry(_path);
        context.action(
          existing == null
              ? 'Wrote $_path, line $index (${entry?.size} B)'
              : 'Appended line $index to $_path (${entry?.size} B)',
        );
      });
      context.changed();
      context.progress(index, count);
      if (index < count && !await context.wait()) {
        return;
      }
    }
  }
}

/// Builds a small directory tree one entry per tick, renames its files, then
/// removes everything bottom up.
class TreeChurnScenario extends FsScenario {
  @override
  String get id => 'tree_churn';

  @override
  String get title => 'A tree built and torn down';

  @override
  String get description =>
      'Makes a/, a/b/, a/b/c/ with a file in each, one entry per second, '
      'renames the files, then deletes everything from the bottom up.';

  @override
  Future<void> run(FsScenarioContext context) async {
    const directories = ['a', 'a/b', 'a/b/c'];
    final files = <String>[];
    final steps = directories.length * 2 + directories.length * 2 + 1;
    var step = 0;
    Future<bool> next() async {
      context.changed();
      context.progress(++step, steps);
      return context.wait();
    }

    context.log('Building the tree');
    for (final directory in directories) {
      await context.attempt('Creating $directory/', () async {
        await context.explorer.createDirectory(directory);
        context.action('Created $directory/');
      });
      if (!await next()) {
        return;
      }
      final file = '$directory/note.txt';
      await context.attempt('Creating $file', () async {
        await context.ensureDirectory(directory);
        await context.explorer.createFile(
          file,
          content: 'A note in $directory\n',
        );
        files.add(file);
        context.action('Created $file');
      });
      if (!await next()) {
        return;
      }
    }

    context.log('Renaming the files');
    final renamed = <String>[];
    for (final file in files) {
      await context.attempt('Renaming $file', () async {
        if (await context.explorer.entry(file) == null) {
          context.warn('$file is gone, nothing to rename');
          return;
        }
        final entry = await context.explorer.rename(file, 'renamed.txt');
        renamed.add(entry.path);
        context.action('Renamed $file to ${entry.name}');
      });
      if (!await next()) {
        return;
      }
    }

    context.log('Tearing the tree down, bottom up');
    for (final file in renamed.reversed) {
      await context.attempt('Deleting $file', () async {
        await context.explorer.delete(file);
        context.action('Deleted $file');
      });
      if (!await next()) {
        return;
      }
    }
    for (final directory in directories.reversed) {
      await context.attempt('Deleting $directory/', () async {
        await context.explorer.delete(directory);
        context.action('Deleted $directory/');
      });
      if (!await next()) {
        return;
      }
    }
    final left = await context.attempt(
      'Listing',
      () => context.explorer.list(),
    );
    context.log(
      left == null || left.isEmpty
          ? 'Nothing left, as expected'
          : '${left.length} entries left: $left',
    );
    context.progress(steps, steps);
  }
}

/// Adds a record to a sembast database every tick for 30 ticks, so the
/// explorer has a database file to open and the tree a file whose size grows.
///
/// The database is opened through the `fs_shim` bridge of the explorer's
/// own file system, and opened again after a failed write: the storage may
/// have been cleared under it.
class SembastRecordsScenario extends FsScenario {
  /// How many records.
  final int count;

  /// Scenario of [count] records.
  SembastRecordsScenario({this.count = 30});

  @override
  String get id => 'sembast_records';

  @override
  String get title => 'Records in a sembast database';

  @override
  String get description =>
      'Adds a record to db/events.db every second for $count seconds. '
      'Tap the file in the tree to browse the records.';

  static const _path = 'db/events.db';

  @override
  Future<void> run(FsScenarioContext context) async {
    final explorer = context.explorer;
    final factory = getDatabaseFactoryFsShim(explorer.fileSystem);
    final store = sembast.intMapStoreFactory.store('event');
    sembast.Database? database;

    Future<sembast.Database> open() async {
      if (await context.ensureDirectory('db')) {
        context.warn('db/ was gone, made it again');
      }
      final db = await factory.openDatabase(explorer.fsPath(_path));
      context.log('Opened $_path (version ${db.version})');
      return db;
    }

    Future<void> close() async {
      final db = database;
      database = null;
      if (db != null) {
        try {
          await db.close();
        } catch (_) {
          // The storage may be gone, the handle with it.
        }
      }
    }

    context.log('Adding $count records to $_path');
    await context.attempt('Creating db/', () async {
      await explorer.createDirectory('db');
      context.action('Created db/');
    });
    for (var index = 1; index <= count; index++) {
      final added = await context.attempt('Adding record $index', () async {
        if (await explorer.entry(_path) == null && database != null) {
          context.warn('$_path is gone, opening it again');
          await close();
        }
        final db = database ??= await open();
        final key = await store.add(db, {
          'index': index,
          'at': Timestamp.now(),
          'message': 'Event $index of $count',
        });
        final entry = await explorer.entry(_path);
        context.action('Added record $key (${entry?.size ?? 0} B on disk)');
        return key;
      });
      if (added == null) {
        // Whatever failed, a fresh handle is the way to go on.
        await close();
      }
      context.changed();
      context.progress(index, count);
      if (index < count && !await context.wait()) {
        await close();
        return;
      }
    }
    final db = database;
    if (db != null) {
      final total = await context.attempt('Counting', () => store.count(db));
      context.log('${total ?? 0} records in the store at the end');
    }
    await close();
    context.changed();
  }
}

/// The scenarios the app offers, in order.
List<FsScenario> fsExplorerScenarios() => [
  CreateFileEverySecondScenario(),
  GrowingFileScenario(),
  TreeChurnScenario(),
  SembastRecordsScenario(),
];
