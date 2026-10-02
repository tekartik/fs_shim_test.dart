import 'dart:async';

import 'package:festenao_common_flutter/file_system_explorer_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../file_system_choice.dart';
import '../scenario/scenario.dart';
import '../scenario/scenarios.dart';
import '../tree/file_system_tree.dart';
import 'open_entry.dart';

/// The directory of [choice] the scenarios run in, `scenarios/` in the app
/// directory, sandboxed: nothing a scenario does leaves it.
Future<FileSystemExplorer> fsScenariosExplorer(FsChoice choice) async {
  final appDirectory = await choice.appDirectory();
  final fileSystem = appDirectory.fs;
  final directory = fileSystem.directory(
    fileSystem.path.join(appDirectory.path, 'scenarios'),
  );
  await directory.create(recursive: true);
  return festenaoDirectoryExplorer(directory);
}

/// The scenario screen: the log of what the scenario does on the left, the
/// tree of the directory it writes to on the right — stacked on a narrow
/// screen.
///
/// The scenarios run in the `scenarios/` directory of the app data of
/// [choice], and only there. "Clear data" wipes it, running scenario or not,
/// the way clearing the site data in a browser would: the scenario reports
/// what it lost and goes on.
class FsScenarioScreen extends StatefulWidget {
  /// The file system the scenarios run in.
  final FsChoice choice;

  /// The scenarios offered, [fsExplorerScenarios] by default.
  final List<FsScenario>? scenarios;

  /// How long a scenario step waits, a second by default.
  final Duration tick;

  /// Scenario screen in [choice].
  const FsScenarioScreen({
    super.key,
    required this.choice,
    this.scenarios,
    this.tick = const Duration(seconds: 1),
  });

  @override
  State<FsScenarioScreen> createState() => _FsScenarioScreenState();
}

class _FsScenarioScreenState extends State<FsScenarioScreen> {
  late final List<FsScenario> _scenarios =
      widget.scenarios ?? fsExplorerScenarios();
  late FsScenario _selected = _scenarios.first;
  late final Future<void> _ready = _setup();
  FsScenarioRunner? _runner;
  FileSystemTreeController? _tree;

  Future<void> _setup() async {
    final explorer = await fsScenariosExplorer(widget.choice);
    final runner = FsScenarioRunner(explorer: explorer, tick: widget.tick);
    final tree = FileSystemTreeController(
      explorer: explorer,
      autoExpandNew: true,
    );
    runner.changes.addListener(() => unawaited(tree.refresh()));
    if (!mounted) {
      runner.dispose();
      tree.dispose();
      return;
    }
    setState(() {
      _runner = runner;
      _tree = tree;
    });
  }

  @override
  void dispose() {
    _runner?.dispose();
    _tree?.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _start() async {
    final runner = _runner;
    if (runner == null || runner.isRunning) {
      return;
    }
    final tree = _tree;
    if (tree != null) {
      // What the other scenarios left closes, so this one is in view; its
      // own directory is made again and the tree opens it by itself, as a
      // new one.
      for (final entry in tree.childrenOf('') ?? const <FileSystemEntry>[]) {
        if (entry.isDirectory && entry.path != _selected.id) {
          tree.collapse(entry.path);
        }
      }
      tree.forget(_selected.id);
    }
    try {
      await runner.start(_selected);
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _stop() => _runner?.stop() ?? Future.value();

  Future<void> _clear() async {
    final runner = _runner;
    if (runner == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear data'),
        content: Text(
          'Delete everything in ${runner.nativePath}?'
          '${runner.isRunning ? '\n\nThe running scenario goes on.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await runner.clear();
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _openEntry(FileSystemEntry entry) async {
    final tree = _tree;
    if (tree == null) {
      return;
    }
    await openFileSystemEntry(context, explorer: tree.explorer, entry: entry);
    await tree.refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Scenarios · ${widget.choice.name}'),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Reload the tree',
          onPressed: () => _tree?.refresh(),
        ),
      ],
    ),
    body: FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('${snapshot.error}'));
        }
        final runner = _runner;
        final tree = _tree;
        if (runner == null || tree == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final left = _ScenarioPane(
              runner: runner,
              scenarios: _scenarios,
              selected: _selected,
              onSelect: (scenario) => setState(() => _selected = scenario),
              onStart: _start,
              onStop: _stop,
              onClear: _clear,
              choice: widget.choice,
            );
            final right = _TreePane(tree: tree, onOpenEntry: _openEntry);
            if (wide) {
              return Row(
                children: [
                  Expanded(flex: 2, child: left),
                  const VerticalDivider(width: 1),
                  Expanded(flex: 3, child: right),
                ],
              );
            }
            return Column(
              children: [
                Expanded(child: left),
                const Divider(height: 1),
                Expanded(child: right),
              ],
            );
          },
        );
      },
    ),
  );
}

/// The left pane: which scenario, the controls, the log.
class _ScenarioPane extends StatelessWidget {
  final FsScenarioRunner runner;
  final List<FsScenario> scenarios;
  final FsScenario selected;
  final ValueChanged<FsScenario> onSelect;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onClear;
  final FsChoice choice;

  const _ScenarioPane({
    required this.runner,
    required this.scenarios,
    required this.selected,
    required this.onSelect,
    required this.onStart,
    required this.onStop,
    required this.onClear,
    required this.choice,
  });

  String get _clearHint {
    if (kIsWeb) {
      return 'Clearing the site data in the browser while it runs has the '
          'same effect: the scenario reports what it lost and goes on.';
    }
    if (choice.id == 'io') {
      return 'Deleting ${runner.nativePath} on the disk while it runs '
          'has the same effect: the scenario reports what it lost and goes on.';
    }
    return 'Clear it while it runs: the scenario reports what it lost and '
        'goes on.';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: runner,
    builder: (context, _) {
      final theme = Theme.of(context);
      final isRunning = runner.isRunning;
      final progress = runner.progress;
      final entries = runner.entries;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: DropdownButtonFormField<FsScenario>(
              initialValue: selected,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Scenario',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final scenario in scenarios)
                  DropdownMenuItem(
                    value: scenario,
                    child: Text(
                      scenario.title,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: isRunning
                  ? null
                  : (scenario) {
                      if (scenario != null) {
                        onSelect(scenario);
                      }
                    },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(selected.description, style: theme.textTheme.bodySmall),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (isRunning)
                  FilledButton.tonalIcon(
                    onPressed: onStop,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                  )
                else
                  FilledButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                  ),
                OutlinedButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Clear data'),
                ),
                ExplorerChip(
                  label: runner.state.name,
                  tone: switch (runner.state) {
                    FsScenarioState.running => ExplorerChipTone.accent,
                    FsScenarioState.failed => ExplorerChipTone.accent,
                    _ => ExplorerChipTone.neutral,
                  },
                ),
                if (progress != null)
                  ExplorerChip(label: '$progress', monospace: true),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: LinearProgressIndicator(
              value: isRunning && progress == null
                  ? null
                  : (progress?.ratio ?? 0),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(
              _clearHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ExplorerSectionHeader(
            label: 'Log',
            trailing: ExplorerChip(label: '${entries.length}'),
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      'Press Start',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    // Newest at the bottom, the list staying there as lines
                    // come in.
                    reverse: true,
                    itemCount: entries.length,
                    itemBuilder: (context, index) =>
                        _LogLine(entry: entries[entries.length - 1 - index]),
                  ),
          ),
        ],
      );
    },
  );
}

class _LogLine extends StatelessWidget {
  final FsScenarioLogEntry entry;

  const _LogLine({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (icon, color) = switch (entry.level) {
      FsScenarioLogLevel.info => (Icons.info_outline, colors.onSurfaceVariant),
      FsScenarioLogLevel.action => (Icons.check_circle_outline, colors.primary),
      FsScenarioLogLevel.warning => (
        Icons.warning_amber_outlined,
        colors.tertiary,
      ),
      FsScenarioLogLevel.error => (Icons.error_outline, colors.error),
      FsScenarioLogLevel.done => (Icons.flag_outlined, colors.primary),
    };
    final time = entry.time;
    String two(int value) => value.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${two(time.hour)}:${two(time.minute)}:${two(time.second)}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(entry.message, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// The right pane: the tree of the scenarios directory.
class _TreePane extends StatelessWidget {
  final FileSystemTreeController tree;
  final void Function(FileSystemEntry entry) onOpenEntry;

  const _TreePane({required this.tree, required this.onOpenEntry});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ExplorerSectionHeader(
        label: 'Files',
        trailing: ListenableBuilder(
          listenable: tree,
          builder: (context, _) {
            final (directories, files) = tree.counts;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExplorerChip(label: '$directories dirs'),
                const SizedBox(width: 4),
                ExplorerChip(label: '$files files'),
              ],
            );
          },
        ),
      ),
      Expanded(
        child: FileSystemTreeView(
          controller: tree,
          rootLabel: 'scenarios',
          onOpenFile: onOpenEntry,
          onOpenDirectory: onOpenEntry,
        ),
      ),
      ExplorerStatusBar(message: tree.explorer.nativePath('')),
    ],
  );
}

/// Pushes a [FsScenarioScreen] in [choice].
Future<void> goToFsScenarioScreen(
  BuildContext context, {
  required FsChoice choice,
  List<FsScenario>? scenarios,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => FsScenarioScreen(choice: choice, scenarios: scenarios),
  ),
);
