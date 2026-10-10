import 'package:flutter_test/flutter_test.dart';
import 'package:fs_explorer_app/fs_explorer_app.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:material_ui/material_ui.dart';

FsChoice _memoryChoice() => FsChoice(
  id: 'memory',
  name: 'Memory',
  description: 'A scratch file system',
  fileSystem: newFileSystemMemory(),
);

/// Pumps between real delays: the file system is really asynchronous, so
/// everything runs in [WidgetTester.runAsync].
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// Pumps between real delays until every finder of [finders] finds one
/// widget, or none for those of [gone], failing after [timeout]: a loaded
/// runner takes far longer than a fixed number of frames to run a scenario
/// or to list a directory.
Future<void> _settleUntil(
  WidgetTester tester,
  List<Finder> finders, {
  List<Finder> gone = const [],
  Duration timeout = const Duration(minutes: 2),
}) async {
  bool done() =>
      finders.every((finder) => finder.evaluate().length == 1) &&
      gone.every((finder) => finder.evaluate().isEmpty);
  final watch = Stopwatch()..start();
  while (!done()) {
    if (watch.elapsed > timeout) {
      fail('$finders, none of $gone: not there after ${watch.elapsed}');
    }
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
  // Until the scenarios directory is made and its tree listed.
  await _settleUntil(tester, [find.text('Start'), find.text('scenarios')]);
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
        // Until the run is over and the tree has listed what it wrote.
        await _settleUntil(tester, [
          find.text('Done, every step went through'),
          find.text('tick_03.txt'),
          find.text('3 files'),
        ]);
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
        await _settleUntil(tester, [], gone: [find.text('tick_01.txt')]);
        expect(find.text('tick_01.txt'), findsNothing);

        // Clear data wipes the tree, the log says so.
        await tester.tap(find.text('Clear data'));
        // The dialog opens in fake time, no file system involved.
        await _settle(tester);
        await tester.tap(find.text('Clear'));
        await _settleUntil(
          tester,
          [find.textContaining('Cleared 1 entry')],
          gone: [find.text('create_file_every_second')],
        );
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
        await _settleUntil(tester, [find.text('Memory')]);
        expect(find.text('fs_shim explorer'), findsOneWidget);
        expect(find.text('Memory'), findsOneWidget);

        await tester.tap(find.text('Memory'));
        await _settleUntil(tester, [find.text('Support')]);
        expect(find.text('Scenarios'), findsOneWidget);
        expect(find.text('App data'), findsOneWidget);
        expect(find.text('Documents'), findsOneWidget);
        expect(find.text('Support'), findsOneWidget);

        await tester.tap(find.text('App data'));
        await _settleUntil(tester, [find.text('0 files')]);
        expect(find.text('tree'), findsOneWidget);
        expect(find.text('0 files'), findsOneWidget);
      });
    });
  });
}
