import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fs_explorer_app/fs_explorer_app.dart';
import 'package:fs_shim/fs_memory.dart';

FsChoice _memoryChoice() => FsChoice(
  id: 'memory',
  name: 'Memory',
  description: 'A scratch file system',
  fileSystem: newFileSystemMemory(),
);

/// Pumps between real delays: the file system is really asynchronous, so
/// everything runs in [WidgetTester.runAsync].
Future<void> _settle(WidgetTester tester, {int times = 10}) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: home));
  await _settle(tester);
}

void main() {
  group('FsScenarioScreen', () {
    testWidgets('runs a scenario, the log left and the tree right', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await _pump(
          tester,
          FsScenarioScreen(
            choice: _memoryChoice(),
            tick: const Duration(milliseconds: 1),
            scenarios: [CreateFileEverySecondScenario(count: 3)],
          ),
          size: const Size(1200, 800),
        );
        expect(find.text('Scenarios · Memory'), findsOneWidget);
        expect(find.text('A file every second'), findsOneWidget);
        expect(find.text('Start'), findsOneWidget);
        expect(find.text('Press Start'), findsOneWidget);
        expect(find.text('scenarios'), findsOneWidget);
        // Side by side: the log pane is left of the tree pane.
        expect(
          tester.getTopLeft(find.text('Start')).dx,
          lessThan(tester.getTopLeft(find.text('scenarios')).dx),
        );

        await tester.tap(find.text('Start'));
        await _settle(tester, times: 30);
        expect(find.text('Done, every step went through'), findsOneWidget);
        expect(find.text('done'), findsOneWidget);
        expect(find.text('3/3'), findsOneWidget);
        expect(
          find.textContaining('Created ticks/tick_03.txt ('),
          findsOneWidget,
        );

        // The tree picked the scenario directory up, open down to the files.
        expect(find.text('create_file_every_second'), findsOneWidget);
        expect(find.text('ticks'), findsOneWidget);
        expect(find.text('tick_01.txt'), findsOneWidget);
        expect(find.text('tick_03.txt'), findsOneWidget);
        expect(find.text('3 files'), findsOneWidget);

        // Collapsed by hand, it stays so.
        await tester.tap(find.text('ticks'));
        await _settle(tester);
        expect(find.text('tick_01.txt'), findsNothing);

        // Clear data wipes the tree, the log says so.
        await tester.tap(find.text('Clear data'));
        await _settle(tester);
        await tester.tap(find.text('Clear'));
        await _settle(tester);
        expect(find.text('tick_01.txt'), findsNothing);
        expect(find.text('create_file_every_second'), findsNothing);
        expect(find.textContaining('Cleared 1 entry'), findsOneWidget);
      });
    });

    testWidgets('stacks the panes on a narrow screen', (tester) async {
      await tester.runAsync(() async {
        await _pump(
          tester,
          FsScenarioScreen(
            choice: _memoryChoice(),
            tick: const Duration(milliseconds: 1),
          ),
          size: const Size(400, 800),
        );
        expect(find.text('Start'), findsOneWidget);
        expect(find.text('scenarios'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Start')).dy,
          lessThan(tester.getTopLeft(find.text('scenarios')).dy),
        );
      });
    });
  });

  group('FsExplorerApp', () {
    testWidgets('goes from the home to a file system and its tree', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final choice = _memoryChoice();
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(FsExplorerApp(choices: [choice]));
        await _settle(tester);
        expect(find.text('fs_shim explorer'), findsOneWidget);
        expect(find.text('Memory'), findsOneWidget);

        await tester.tap(find.text('Memory'));
        await _settle(tester);
        expect(find.text('Scenarios'), findsOneWidget);
        expect(find.text('App data'), findsOneWidget);
        expect(find.text('Documents'), findsOneWidget);
        expect(find.text('Support'), findsOneWidget);

        await tester.tap(find.text('App data'));
        await _settle(tester);
        expect(find.text('tree'), findsOneWidget);
        expect(find.text('0 files'), findsOneWidget);
      });
    });
  });
}
