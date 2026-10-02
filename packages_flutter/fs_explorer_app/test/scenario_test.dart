import 'package:festenao_common/fs/file_system_explorer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fs_explorer_app/fs_explorer_app.dart';
import 'package:fs_shim/fs_memory.dart';

Future<FileSystemExplorer> _newExplorer() async {
  final fs = newFileSystemMemory();
  await fs.directory('scenarios').create(recursive: true);
  return FileSystemExplorer(fileSystem: fs, rootPath: 'scenarios');
}

const _tick = Duration(milliseconds: 1);

/// Waits until [condition] holds.
Future<void> _until(bool Function() condition) async {
  while (!condition()) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void main() {
  group('FsScenarioRunner', () {
    test('creates a file every tick', () async {
      final explorer = await _newExplorer();
      final runner = FsScenarioRunner(explorer: explorer, tick: _tick);
      expect(runner.state, FsScenarioState.idle);
      await runner.start(CreateFileEverySecondScenario(count: 5));
      expect(runner.state, FsScenarioState.done);
      expect(runner.failures, 0);
      expect(runner.progress.toString(), '5/5');
      expect(runner.entries.last.level, FsScenarioLogLevel.done);
      expect(runner.changes.value, greaterThan(0));

      final files = await explorer.list('create_file_every_second/ticks');
      expect(files.map((entry) => entry.name), [
        'tick_01.txt',
        'tick_02.txt',
        'tick_03.txt',
        'tick_04.txt',
        'tick_05.txt',
      ]);
      expect(
        await explorer.readAsString(
          'create_file_every_second/ticks/tick_03.txt',
        ),
        startsWith('Tick 3 of 5 at '),
      );
      expect(
        runner.entries.where(
          (entry) =>
              entry.level == FsScenarioLogLevel.action &&
              entry.message.startsWith('Created ticks/tick_'),
        ),
        hasLength(5),
      );
      runner.dispose();
    });

    test('a second run starts from an empty directory', () async {
      final explorer = await _newExplorer();
      final runner = FsScenarioRunner(explorer: explorer, tick: _tick);
      await runner.start(CreateFileEverySecondScenario(count: 3));
      await explorer.createFile('create_file_every_second/leftover.txt');
      await runner.start(CreateFileEverySecondScenario(count: 2));
      expect(runner.failures, 0);
      final entries = await explorer.list('create_file_every_second');
      expect(entries.map((entry) => entry.name), ['ticks']);
      expect(
        await explorer.list('create_file_every_second/ticks'),
        hasLength(2),
      );
      runner.dispose();
    });

    test('stop ends the scenario at its next wait', () async {
      final explorer = await _newExplorer();
      final runner = FsScenarioRunner(
        explorer: explorer,
        tick: const Duration(seconds: 10),
      );
      final running = runner.start(CreateFileEverySecondScenario(count: 1000));
      expect(runner.isRunning, isTrue);
      expect(() => runner.start(GrowingFileScenario()), throwsStateError);
      await _until(
        () => runner.entries.any(
          (entry) => entry.level == FsScenarioLogLevel.action,
        ),
      );
      // The scenario is waiting ten seconds: stop wakes it up.
      await runner.stop();
      await running;
      expect(runner.state, FsScenarioState.stopped);
      expect(runner.entries.last.message, 'Stopped');
      expect(
        await explorer.list('create_file_every_second/ticks'),
        hasLength(1),
      );
      runner.dispose();
    });

    test('clearing the data while running does not stop it', () async {
      final explorer = await _newExplorer();
      final runner = FsScenarioRunner(
        explorer: explorer,
        tick: const Duration(milliseconds: 5),
      );
      final running = runner.start(CreateFileEverySecondScenario(count: 20));
      await _until(
        () =>
            runner.entries
                .where((entry) => entry.level == FsScenarioLogLevel.action)
                .length >=
            5,
      );
      await runner.clear();
      await running;
      expect(runner.state, FsScenarioState.done);
      expect(runner.failures, 0);
      final files = await explorer.list('create_file_every_second/ticks');
      expect(files, isNotEmpty);
      expect(files.length, lessThan(20));
      expect(files.last.name, 'tick_20.txt');
      expect(
        runner.entries.any(
          (entry) =>
              entry.level == FsScenarioLogLevel.warning &&
              entry.message.contains('was gone'),
        ),
        isTrue,
      );
      expect(
        runner.entries.any((entry) => entry.message.startsWith('Cleared')),
        isTrue,
      );
      runner.dispose();
    });

    test('a step that throws is logged and the scenario goes on', () async {
      final explorer = await _newExplorer();
      final runner = FsScenarioRunner(explorer: explorer, tick: _tick);
      await runner.start(_ThrowingScenario());
      expect(runner.state, FsScenarioState.done);
      expect(runner.failures, 1);
      expect(
        runner.entries.map((entry) => entry.toString()),
        containsAllInOrder([
          '[error] Step 1 failed: Bad state: boom',
          '[action] Step 2 went through',
          '[done] Done, 1 step failed',
        ]),
      );
      runner.dispose();
    });

    test('a scenario that throws out of run fails', () async {
      final explorer = await _newExplorer();
      final runner = FsScenarioRunner(explorer: explorer, tick: _tick);
      await runner.start(_CrashingScenario());
      expect(runner.state, FsScenarioState.failed);
      expect(runner.entries.last.message, 'Failed: Exception: crash');
      runner.dispose();
    });

    for (final scenario in fsExplorerScenarios()) {
      test('${scenario.id} runs to the end without a failure', () async {
        final explorer = await _newExplorer();
        final runner = FsScenarioRunner(explorer: explorer, tick: _tick);
        await runner.start(scenario);
        expect(runner.state, FsScenarioState.done, reason: '${runner.entries}');
        expect(runner.failures, 0, reason: '${runner.entries}');
        expect(runner.progress?.ratio, 1);
        runner.dispose();
      });
    }

    test('the records scenario leaves a sembast database', () async {
      final explorer = await _newExplorer();
      final runner = FsScenarioRunner(explorer: explorer, tick: _tick);
      await runner.start(SembastRecordsScenario(count: 4));
      expect(runner.failures, 0);
      final entry = await explorer.entry('sembast_records/db/events.db');
      expect(entry?.kind, FileSystemEntryKind.database);
      expect(
        await explorer.databaseKind('sembast_records/db/events.db'),
        FileSystemDatabaseKind.sembast,
      );
      expect(
        runner.entries.any(
          (entry) => entry.message == '4 records in the store at the end',
        ),
        isTrue,
      );
      runner.dispose();
    });

    test('the growing file grows', () async {
      final explorer = await _newExplorer();
      final runner = FsScenarioRunner(explorer: explorer, tick: _tick);
      await runner.start(GrowingFileScenario(count: 3));
      final content = await explorer.readAsString(
        'growing_file/growing/journal.txt',
      );
      expect(
        content.split('\n').where((line) => line.isNotEmpty),
        hasLength(3),
      );
      runner.dispose();
    });

    test('the tree churn leaves nothing', () async {
      final explorer = await _newExplorer();
      final runner = FsScenarioRunner(explorer: explorer, tick: _tick);
      await runner.start(TreeChurnScenario());
      expect(await explorer.list('tree_churn'), isEmpty);
      expect(
        runner.entries.any(
          (entry) => entry.message == 'Nothing left, as expected',
        ),
        isTrue,
      );
      runner.dispose();
    });
  });

  group('FsChoice', () {
    test('the app directory sits in the support directory', () async {
      final choice = FsChoice(
        id: 'memory',
        name: 'Memory',
        description: '',
        fileSystem: newFileSystemMemory(),
      );
      final directory = await choice.appDirectory();
      expect(directory.path, '/support/fs_explorer_app');
      expect(await directory.exists(), isTrue);
      expect(choice.isPlatform, isFalse);
      final explorer = await fsScenariosExplorer(choice);
      expect(explorer.fileSystem.name, contains('sandbox'));
      expect(await explorer.list(), isEmpty);
      // The sandbox is the point: nothing above the scenarios directory.
      expect(() => explorer.fsPath('../other'), throwsA(isA<Exception>()));
    });
  });
}

class _ThrowingScenario extends FsScenario {
  @override
  String get id => 'throwing';

  @override
  String get title => 'Throwing';

  @override
  String get description => '';

  @override
  Future<void> run(FsScenarioContext context) async {
    await context.attempt('Step 1', () async => throw StateError('boom'));
    await context.wait();
    await context.attempt('Step 2', () async {
      context.action('Step 2 went through');
    });
  }
}

class _CrashingScenario extends FsScenario {
  @override
  String get id => 'crashing';

  @override
  String get title => 'Crashing';

  @override
  String get description => '';

  @override
  Future<void> run(FsScenarioContext context) async {
    throw Exception('crash');
  }
}
