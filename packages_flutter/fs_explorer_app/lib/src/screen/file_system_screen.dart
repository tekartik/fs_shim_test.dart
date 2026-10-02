import 'package:festenao_common_flutter/file_system_explorer_flutter.dart';
import 'package:flutter/material.dart';
import 'package:fs_shim/fs.dart' show Directory;

import '../file_system_choice.dart';
import 'open_entry.dart';
import 'scenario_screen.dart';
import 'tree_screen.dart';

/// One file system: what it supports, where it can be browsed from, and its
/// scenarios.
///
/// The roots are the ones `path_provider` names through
/// `tekartik_app_flutter_fs` — documents, support, temporary, downloads,
/// external storage, current directory — the app data directory first. Each
/// opens as a tree, or as a list from its trailing button, sandboxed so the
/// explorer cannot leave it.
class FsFileSystemScreen extends StatefulWidget {
  /// The file system.
  final FsChoice choice;

  /// Screen of [choice].
  const FsFileSystemScreen({super.key, required this.choice});

  @override
  State<FsFileSystemScreen> createState() => _FsFileSystemScreenState();
}

class _FsFileSystemScreenState extends State<FsFileSystemScreen> {
  FsChoice get choice => widget.choice;

  late Future<List<(String name, String? description, Directory directory)>>
  _loading = _resolve();
  var _isReadOnly = false;

  Future<List<(String, String?, Directory)>> _resolve() async {
    final resolved = <(String, String?, Directory)>[
      ('App data', 'Where the scenarios run', await choice.appDirectory()),
    ];
    for (final root in festenaoFileSystemRoots(
      fileSystem: choice.fileSystem,
      packageName: fsExplorerAppPackageName,
    )) {
      // The memory root of the picker is a new file system each time, the
      // app has one of its own.
      if (root.name == 'Memory') {
        continue;
      }
      final directory = await root.resolve();
      if (directory != null) {
        resolved.add((root.name, root.description, directory));
      }
    }
    return resolved;
  }

  FileSystemExplorer _explorer(Directory directory) =>
      festenaoDirectoryExplorer(directory, isReadOnly: _isReadOnly);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileSystem = choice.fileSystem;
    return Scaffold(
      appBar: AppBar(
        title: Text(choice.name),
        actions: [
          IconButton(
            icon: Icon(_isReadOnly ? Icons.lock_outline : Icons.lock_open),
            tooltip: _isReadOnly ? 'Read only' : 'Read write',
            onPressed: () => setState(() => _isReadOnly = !_isReadOnly),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: () => setState(() => _loading = _resolve()),
          ),
        ],
      ),
      body: FutureBuilder<List<(String, String?, Directory)>>(
        future: _loading,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final roots = snapshot.data;
          if (roots == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  choice.description,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ExplorerChip(
                      label: fileSystem.name,
                      monospace: true,
                      tone: ExplorerChipTone.accent,
                    ),
                    ExplorerChip(
                      label: fileSystem.supportsLink ? 'links' : 'no links',
                    ),
                    ExplorerChip(
                      label: fileSystem.supportsFileLink
                          ? 'file links'
                          : 'no file links',
                    ),
                    ExplorerChip(
                      label: fileSystem.supportsRandomAccess
                          ? 'random access'
                          : 'no random access',
                    ),
                    ExplorerChip(
                      label: _isReadOnly ? 'read only' : 'read write',
                      icon: _isReadOnly ? Icons.lock_outline : Icons.lock_open,
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: const Text('Scenarios'),
                subtitle: const Text(
                  'Watch a scenario write to the file system, step by step',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => goToFsScenarioScreen(context, choice: choice),
              ),
              const Divider(),
              const ExplorerSectionHeader(label: 'Browse from'),
              for (final (name, description, directory) in roots)
                ListTile(
                  leading: const Icon(Icons.folder_open_outlined),
                  title: Text(name),
                  subtitle: Text(
                    description == null
                        ? directory.path
                        : '$description\n${directory.path}',
                  ),
                  isThreeLine: description != null,
                  trailing: IconButton(
                    icon: const Icon(Icons.list),
                    tooltip: 'Open as a list',
                    onPressed: () => goToFileSystemExplorerScreen(
                      context,
                      explorer: _explorer(directory),
                      createActions: fsExplorerCreateActions(),
                    ),
                  ),
                  onTap: () => goToFileSystemTreeScreen(
                    context,
                    explorer: _explorer(directory),
                    title: name,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Pushes a [FsFileSystemScreen] on [choice].
Future<void> goToFsFileSystemScreen(
  BuildContext context, {
  required FsChoice choice,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(builder: (_) => FsFileSystemScreen(choice: choice)),
);
