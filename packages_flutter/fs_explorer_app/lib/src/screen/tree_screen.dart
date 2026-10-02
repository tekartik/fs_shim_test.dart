import 'package:festenao_common_flutter/file_system_explorer_flutter.dart';
import 'package:flutter/material.dart';

import '../tree/file_system_tree.dart';
import 'open_entry.dart';

/// A screen browsing a [FileSystemExplorer] as a tree.
///
/// A directory expands on tap, a file opens with what fits it (see
/// [openFileSystemEntry]), and the trailing button of a directory opens it in
/// the list screen, where files are created, renamed and deleted.
class FileSystemTreeScreen extends StatefulWidget {
  /// The file system browsed.
  final FileSystemExplorer explorer;

  /// What the app bar says, the explorer title by default.
  final String? title;

  /// Tree screen of [explorer].
  const FileSystemTreeScreen({super.key, required this.explorer, this.title});

  @override
  State<FileSystemTreeScreen> createState() => _FileSystemTreeScreenState();
}

class _FileSystemTreeScreenState extends State<FileSystemTreeScreen> {
  late final _controller = FileSystemTreeController(explorer: widget.explorer);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open(FileSystemEntry entry) async {
    await openFileSystemEntry(context, explorer: widget.explorer, entry: entry);
    await _controller.refresh();
  }

  @override
  Widget build(BuildContext context) => ExplorerScaffold(
    title: widget.title ?? widget.explorer.title,
    isReadOnly: widget.explorer.isReadOnly,
    stateChip: const ExplorerChip(
      label: 'tree',
      icon: Icons.account_tree_outlined,
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.refresh),
        tooltip: 'Reload',
        onPressed: _controller.refresh,
      ),
    ],
    statusBar: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final (directories, files) = _controller.counts;
        return ExplorerStatusBar(
          message: widget.explorer.fileSystem.name,
          trailing: [
            ExplorerChip(label: '$directories dirs'),
            ExplorerChip(label: '$files files'),
          ],
        );
      },
    ),
    body: FileSystemTreeView(
      controller: _controller,
      rootLabel: widget.title ?? widget.explorer.title,
      onOpenFile: _open,
      onOpenDirectory: _open,
    ),
  );
}

/// Pushes a [FileSystemTreeScreen] on [explorer].
Future<void> goToFileSystemTreeScreen(
  BuildContext context, {
  required FileSystemExplorer explorer,
  String? title,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => FileSystemTreeScreen(explorer: explorer, title: title),
  ),
);
