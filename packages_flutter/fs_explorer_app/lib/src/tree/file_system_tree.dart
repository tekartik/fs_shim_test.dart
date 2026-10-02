import 'dart:async';

import 'package:festenao_common_flutter/file_system_explorer_flutter.dart';
import 'package:flutter/material.dart';

/// One visible row of a [FileSystemTreeController]: an entry and how deep it
/// sits, the root being depth 0.
class FileSystemTreeRow {
  /// The entry, the root one for the first row.
  final FileSystemEntry entry;

  /// How many levels below the root, 0 for the root itself.
  final int depth;

  /// True when the directory is expanded.
  final bool isExpanded;

  /// True while the directory is being listed.
  final bool isLoading;

  /// What listing the directory threw, null when it did not.
  final Object? error;

  /// Row of [entry] at [depth].
  const FileSystemTreeRow({
    required this.entry,
    required this.depth,
    this.isExpanded = false,
    this.isLoading = false,
    this.error,
  });

  /// The path of the entry, `''` for the root.
  String get path => entry.path;

  @override
  String toString() => '${'  ' * depth}${entry.name}';
}

/// The state of a tree over a [FileSystemExplorer]: which directories are
/// expanded and what each one listed last.
///
/// Listings are loaded when a directory is expanded, and [refresh] lists
/// every expanded directory again — what a screen calls when something else
/// writes to the file system, a scenario for one. A refresh in progress
/// coalesces with the next one asked for, and an expanded directory that is
/// gone collapses.
class FileSystemTreeController extends ChangeNotifier {
  /// The file system browsed, from its root.
  final FileSystemExplorer explorer;

  /// True to expand a directory that appears in an expanded one on a
  /// [refresh] — what a scenario makes shows up open. A directory collapsed
  /// by hand stays so: it is no longer new.
  final bool autoExpandNew;

  final _expanded = <String>{''};
  final _children = <String, List<FileSystemEntry>>{};
  final _loading = <String>{};
  final _errors = <String, Object>{};
  Future<void>? _refreshing;
  var _refreshAgain = false;
  var _disposed = false;

  /// Tree over [explorer], the root expanded and listed straight away.
  FileSystemTreeController({
    required this.explorer,
    this.autoExpandNew = false,
  }) {
    unawaited(_load(''));
  }

  /// True when the directory [path] is expanded.
  bool isExpanded(String path) => _expanded.contains(path);

  /// The last listing of the directory [path], null when it was never listed.
  List<FileSystemEntry>? childrenOf(String path) => _children[path];

  /// How many directories and files the tree shows, the root left out.
  (int directories, int files) get counts {
    var directories = 0;
    var files = 0;
    for (final row in rows.skip(1)) {
      if (row.entry.isDirectory) {
        directories++;
      } else {
        files++;
      }
    }
    return (directories, files);
  }

  /// Expands the directory [path], listing it.
  Future<void> expand(String path) async {
    if (_expanded.add(path)) {
      notifyListeners();
    }
    await _load(path);
  }

  /// Collapses the directory [path]; what it listed is kept for the next
  /// expand.
  void collapse(String path) {
    if (_expanded.remove(path)) {
      notifyListeners();
    }
  }

  /// Forgets what was listed at [path] and below, and that its parent listed
  /// it: at the next [refresh] it is new, opened by itself when
  /// [autoExpandNew] — what a screen calls right before something makes the
  /// directory again.
  void forget(String path) {
    if (path.isEmpty) {
      return;
    }
    _forgetSubtree(path);
    final parent = _parentOf(path);
    final siblings = _children[parent];
    if (siblings != null) {
      _children[parent] = siblings
          .where((entry) => entry.path != path)
          .toList();
    }
    notifyListeners();
  }

  /// Drops the listings and the expanded state of [path] and everything
  /// below it.
  void _forgetSubtree(String path) {
    bool inside(String other) => other == path || other.startsWith('$path/');
    _children.removeWhere((key, _) => inside(key));
    _expanded.removeWhere(inside);
  }

  static String _parentOf(String path) {
    final slash = path.lastIndexOf('/');
    return slash < 0 ? '' : path.substring(0, slash);
  }

  /// Expands or collapses the directory [path].
  Future<void> toggle(String path) =>
      isExpanded(path) ? Future.sync(() => collapse(path)) : expand(path);

  /// Lists every expanded directory again.
  Future<void> refresh() {
    final running = _refreshing;
    if (running != null) {
      _refreshAgain = true;
      return running;
    }
    final future = _refreshing = _refreshAll();
    return future;
  }

  Future<void> _refreshAll() async {
    try {
      do {
        _refreshAgain = false;
        // The root first then down: a directory gone from its parent's
        // listing collapses before it is listed.
        for (final path in _expandedTopDown()) {
          if (_disposed) {
            return;
          }
          if (path.isNotEmpty && !_isListedByParent(path)) {
            _expanded.remove(path);
            _children.remove(path);
            continue;
          }
          await _load(path);
        }
      } while (_refreshAgain);
    } finally {
      _refreshing = null;
    }
  }

  List<String> _expandedTopDown() =>
      _expanded.toList()..sort((a, b) => a.length.compareTo(b.length));

  bool _isListedByParent(String path) {
    final siblings = _children[_parentOf(path)];
    if (siblings == null) {
      return false;
    }
    return siblings.any((entry) => entry.path == path && entry.isDirectory);
  }

  /// Lists [path]; [isNew] for a directory that just appeared, whose whole
  /// subtree is new too.
  Future<void> _load(String path, {bool isNew = false}) async {
    _loading.add(path);
    notifyListeners();
    try {
      final entries = await explorer.list(path);
      if (_disposed) {
        return;
      }
      final previous = _children[path];
      _children[path] = entries;
      _errors.remove(path);
      // A directory that was not there at the last listing opens by itself
      // when asked to, its subtree with it; the first listing of a directory
      // expanded by hand opens nothing more.
      if (autoExpandNew && (isNew || previous != null)) {
        final known = isNew
            ? const <String>{}
            : previous!.map((entry) => entry.path).toSet();
        for (final entry in entries) {
          if (entry.isDirectory && !known.contains(entry.path)) {
            _expanded.add(entry.path);
            await _load(entry.path, isNew: true);
          }
        }
      }
      // Children that are no longer there are forgotten with their parent
      // listing, so the rows never show what the file system lost.
      final listed = entries.map((entry) => entry.path).toSet();
      for (final child in _children.keys.toList()) {
        if (_isBelow(child, path) && !listed.contains(child)) {
          _forgetSubtree(child);
        }
      }
    } catch (e) {
      if (_disposed) {
        return;
      }
      _errors[path] = e;
    } finally {
      _loading.remove(path);
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  static bool _isBelow(String child, String parent) {
    if (parent.isEmpty) {
      return child.isNotEmpty && !child.contains('/');
    }
    final prefix = '$parent/';
    return child.startsWith(prefix) &&
        !child.substring(prefix.length).contains('/');
  }

  /// The visible rows, the root first, each expanded directory followed by
  /// what it listed.
  List<FileSystemTreeRow> get rows {
    final rows = <FileSystemTreeRow>[];
    void add(FileSystemEntry entry, int depth) {
      final expanded = entry.isDirectory && isExpanded(entry.path);
      rows.add(
        FileSystemTreeRow(
          entry: entry,
          depth: depth,
          isExpanded: expanded,
          isLoading: _loading.contains(entry.path),
          error: _errors[entry.path],
        ),
      );
      if (expanded) {
        for (final child
            in _children[entry.path] ?? const <FileSystemEntry>[]) {
          add(child, depth + 1);
        }
      }
    }

    add(FileSystemEntry(path: '', kind: FileSystemEntryKind.directory), 0);
    return rows;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// A file system as a tree: the root, then each expanded directory indented
/// below it.
///
/// A directory row expands and collapses on tap; a file row calls
/// [onOpenFile]. [onOpenDirectory] adds a trailing button on directory rows,
/// for a screen that lists the directory another way.
class FileSystemTreeView extends StatelessWidget {
  /// The tree displayed.
  final FileSystemTreeController controller;

  /// What the root row is named, the explorer title by default.
  final String? rootLabel;

  /// Called when a file row is tapped.
  final void Function(FileSystemEntry entry)? onOpenFile;

  /// Called from the trailing button of a directory row, hidden when null.
  final void Function(FileSystemEntry entry)? onOpenDirectory;

  /// Tree view of [controller].
  const FileSystemTreeView({
    super.key,
    required this.controller,
    this.rootLabel,
    this.onOpenFile,
    this.onOpenDirectory,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final rows = controller.rows;
      return ListView.builder(
        itemCount: rows.length,
        itemBuilder: (context, index) =>
            _FileSystemTreeRowTile(row: rows[index], view: this),
      );
    },
  );
}

class _FileSystemTreeRowTile extends StatelessWidget {
  final FileSystemTreeRow row;
  final FileSystemTreeView view;

  const _FileSystemTreeRowTile({required this.row, required this.view});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = row.entry;
    final isDirectory = entry.isDirectory;
    final name = row.depth == 0
        ? (view.rootLabel ?? view.controller.explorer.title)
        : entry.name;
    final Widget leading;
    if (!isDirectory) {
      leading = const SizedBox(width: 24);
    } else if (row.isLoading) {
      leading = const SizedBox(
        width: 24,
        height: 24,
        child: Padding(
          padding: EdgeInsets.all(6),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else {
      leading = Icon(
        row.isExpanded ? Icons.expand_more : Icons.chevron_right,
        size: 24,
      );
    }
    final error = row.error;
    return InkWell(
      onTap: () {
        if (isDirectory) {
          view.controller.toggle(entry.path);
        } else {
          view.onOpenFile?.call(entry);
        }
      },
      child: Padding(
        padding: EdgeInsets.only(
          left: 8 + row.depth * 20.0,
          right: 8,
          top: 4,
          bottom: 4,
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 4),
            Icon(
              isDirectory && row.isExpanded
                  ? Icons.folder_open_outlined
                  : fileSystemEntryIcon(entry.kind),
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (error != null)
              ExplorerChip(
                label: 'error',
                tone: ExplorerChipTone.accent,
                tooltip: '$error',
              )
            else if (!isDirectory) ...[
              if (entry.isDatabase)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: ExplorerChip(
                    label: 'database',
                    tone: ExplorerChipTone.accent,
                  ),
                ),
              ExplorerChip(label: fileSystemFormatSize(entry.size)),
            ] else if (row.isExpanded) ...[
              ExplorerChip(
                label: '${view.controller.childrenOf(entry.path)?.length ?? 0}',
                tooltip: 'Entries',
              ),
            ],
            if (isDirectory && view.onOpenDirectory != null)
              IconButton(
                icon: const Icon(Icons.list, size: 20),
                tooltip: 'Open as a list',
                visualDensity: VisualDensity.compact,
                onPressed: () => view.onOpenDirectory!(entry),
              ),
          ],
        ),
      ),
    );
  }
}
