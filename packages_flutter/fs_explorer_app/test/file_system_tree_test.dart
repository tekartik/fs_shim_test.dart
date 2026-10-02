import 'package:festenao_common/fs/file_system_explorer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fs_explorer_app/fs_explorer_app.dart';
import 'package:fs_shim/fs_memory.dart';

Future<FileSystemExplorer> _newExplorer() async {
  final fs = newFileSystemMemory();
  await fs.file('root/sub/deep/note.txt').create(recursive: true);
  await fs.file('root/sub/deep/note.txt').writeAsString('hello');
  await fs.file('root/config.json').create(recursive: true);
  await fs.file('root/config.json').writeAsString('{}');
  return FileSystemExplorer(fileSystem: fs, rootPath: 'root');
}

/// Waits until no directory is being listed.
Future<void> _idle(FileSystemTreeController controller) async {
  while (controller.rows.any((row) => row.isLoading)) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

List<String> _names(FileSystemTreeController controller) => controller.rows
    .map((row) => '${'  ' * row.depth}${row.entry.name}')
    .toList();

/// Pumps between real delays: the memory file system is really
/// asynchronous, so everything runs in [WidgetTester.runAsync].
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  group('FileSystemTreeController', () {
    test('lists the root and expands directories', () async {
      final controller = FileSystemTreeController(
        explorer: await _newExplorer(),
      );
      expect(controller.rows.single.isLoading, isTrue);
      await _idle(controller);
      expect(_names(controller), ['/', '  sub', '  config.json']);
      expect(controller.isExpanded(''), isTrue);
      expect(controller.isExpanded('sub'), isFalse);
      expect(controller.counts, (1, 1));

      await controller.expand('sub');
      expect(_names(controller), ['/', '  sub', '    deep', '  config.json']);
      await controller.expand('sub/deep');
      expect(_names(controller), [
        '/',
        '  sub',
        '    deep',
        '      note.txt',
        '  config.json',
      ]);
      expect(controller.rows[3].depth, 3);
      expect(controller.rows[3].entry.size, 5);
      expect(controller.counts, (2, 2));
      controller.dispose();
    });

    test('collapse keeps the listing, refresh picks up changes', () async {
      final explorer = await _newExplorer();
      final controller = FileSystemTreeController(explorer: explorer);
      await _idle(controller);
      await controller.expand('sub');
      controller.collapse('sub');
      expect(_names(controller), ['/', '  sub', '  config.json']);
      expect(controller.childrenOf('sub'), hasLength(1));
      await controller.toggle('sub');
      expect(controller.isExpanded('sub'), isTrue);

      await explorer.createFile('sub/new.txt', content: 'new');
      await explorer.createFile('other.txt');
      expect(_names(controller), ['/', '  sub', '    deep', '  config.json']);
      await controller.refresh();
      expect(_names(controller), [
        '/',
        '  sub',
        '    deep',
        '    new.txt',
        '  config.json',
        '  other.txt',
      ]);
      controller.dispose();
    });

    test(
      'an expanded directory that is deleted collapses on refresh',
      () async {
        final explorer = await _newExplorer();
        final controller = FileSystemTreeController(explorer: explorer);
        await _idle(controller);
        await controller.expand('sub');
        await controller.expand('sub/deep');
        await explorer.delete('sub');
        await controller.refresh();
        expect(_names(controller), ['/', '  config.json']);
        expect(controller.isExpanded('sub'), isFalse);
        expect(controller.isExpanded('sub/deep'), isFalse);
        expect(controller.childrenOf('sub'), isNull);

        // Made again: a plain directory, collapsed.
        await explorer.createDirectory('sub');
        await controller.refresh();
        expect(_names(controller), ['/', '  sub', '  config.json']);
        expect(controller.isExpanded('sub'), isFalse);
        controller.dispose();
      },
    );

    test('a root that is not there lists nothing', () async {
      final controller = FileSystemTreeController(
        explorer: FileSystemExplorer(
          fileSystem: newFileSystemMemory(),
          rootPath: 'missing',
        ),
      );
      await _idle(controller);
      expect(_names(controller), ['/']);
      expect(controller.rows.single.error, isNull);
      controller.dispose();
    });

    test('a new directory opens by itself when asked to', () async {
      final explorer = await _newExplorer();
      final controller = FileSystemTreeController(
        explorer: explorer,
        autoExpandNew: true,
      );
      await _idle(controller);
      // Expanding by hand opens only what was tapped.
      await controller.expand('sub');
      expect(controller.isExpanded('sub/deep'), isFalse);

      await explorer.createFile('fresh/inner/file.txt');
      await controller.refresh();
      expect(controller.isExpanded('fresh'), isTrue);
      expect(controller.isExpanded('fresh/inner'), isTrue);
      expect(_names(controller), [
        '/',
        '  fresh',
        '    inner',
        '      file.txt',
        '  sub',
        '    deep',
        '  config.json',
      ]);

      // Collapsed by hand, it stays so: it is no longer new.
      controller.collapse('fresh');
      await explorer.createFile('fresh/other.txt');
      await controller.refresh();
      expect(controller.isExpanded('fresh'), isFalse);
      controller.dispose();
    });

    test('a forgotten directory is new again', () async {
      final explorer = await _newExplorer();
      final controller = FileSystemTreeController(
        explorer: explorer,
        autoExpandNew: true,
      );
      await _idle(controller);
      await controller.expand('sub');
      controller.collapse('sub');
      expect(controller.childrenOf('sub'), isNotNull);

      // Made again, as a scenario does with its directory.
      controller.forget('sub');
      expect(controller.childrenOf('sub'), isNull);
      expect(_names(controller), ['/', '  config.json']);
      await explorer.delete('sub');
      await explorer.createFile('sub/again/file.txt');
      await controller.refresh();
      expect(_names(controller), [
        '/',
        '  sub',
        '    again',
        '      file.txt',
        '  config.json',
      ]);
      controller.dispose();
    });

    test('concurrent refreshes coalesce', () async {
      final explorer = await _newExplorer();
      final controller = FileSystemTreeController(explorer: explorer);
      await _idle(controller);
      final first = controller.refresh();
      final second = controller.refresh();
      expect(identical(first, second), isTrue);
      await first;
      expect(_names(controller), ['/', '  sub', '  config.json']);
      controller.dispose();
    });
  });

  group('FileSystemTreeView', () {
    testWidgets('expands on tap and opens a file', (tester) async {
      await tester.runAsync(() async {
        final controller = FileSystemTreeController(
          explorer: await _newExplorer(),
        );
        FileSystemEntry? opened;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FileSystemTreeView(
                controller: controller,
                rootLabel: 'root',
                onOpenFile: (entry) => opened = entry,
              ),
            ),
          ),
        );
        await _settle(tester);
        expect(find.text('root'), findsOneWidget);
        expect(find.text('sub'), findsOneWidget);
        expect(find.text('config.json'), findsOneWidget);
        expect(find.text('deep'), findsNothing);

        await tester.tap(find.text('sub'));
        await _settle(tester);
        expect(find.text('deep'), findsOneWidget);
        await tester.tap(find.text('deep'));
        await _settle(tester);
        expect(find.text('note.txt'), findsOneWidget);
        expect(find.text('5 B'), findsOneWidget);

        await tester.tap(find.text('note.txt'));
        await _settle(tester);
        expect(opened?.path, 'sub/deep/note.txt');

        await tester.tap(find.text('sub'));
        await _settle(tester);
        expect(find.text('deep'), findsNothing);
        controller.dispose();
      });
    });
  });
}
