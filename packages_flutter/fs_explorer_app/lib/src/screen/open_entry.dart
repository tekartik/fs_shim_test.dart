import 'package:festenao_common_flutter/file_system_explorer_flutter.dart';
import 'package:flutter/material.dart';

/// The `+` menu of a list screen: the default files plus a populated demo of
/// each kind the explorer handles.
List<FileSystemCreateAction> fsExplorerCreateActions() => [
  ...defaultFileSystemCreateActions(),
  ...festenaoFileSystemDemoActions(),
];

/// Opens [entry] of [explorer] with what fits it, as the list screen does: a
/// directory in a list screen, a json or yaml document in the object editor,
/// a database in the object explorer, a text file in the text editor,
/// anything else in the hex editor.
Future<void> openFileSystemEntry(
  BuildContext context, {
  required FileSystemExplorer explorer,
  required FileSystemEntry entry,
}) async {
  switch (entry.kind) {
    case FileSystemEntryKind.directory:
      await goToFileSystemExplorerScreen(
        context,
        explorer: explorer,
        path: entry.path,
        createActions: fsExplorerCreateActions(),
      );
    case FileSystemEntryKind.json:
    case FileSystemEntryKind.yaml:
      await goToObjectEditorScreen(
        context,
        source: explorer.objectSource(entry.path),
        title: entry.name,
      );
    case FileSystemEntryKind.database:
      FileSystemDatabase database;
      try {
        database = await explorer.openDatabase(entry.path);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  '${entry.name} is not a sembast nor an sdb database ($e)',
                ),
              ),
            );
        }
        return;
      }
      try {
        if (!context.mounted) {
          return;
        }
        await goToObjectExplorerScreen(
          context,
          repository: database.repository,
          infoChips: [
            ExplorerChip(label: database.kind.name),
            ExplorerChip(label: database.engine, monospace: true),
            ExplorerChip(label: 'v${database.version}'),
          ],
        );
      } finally {
        await database.close();
      }
    case FileSystemEntryKind.text:
      await goToFileSystemTextFileScreen(
        context,
        explorer: explorer,
        path: entry.path,
      );
    case FileSystemEntryKind.binary:
      await goToFileSystemHexFileScreen(
        context,
        explorer: explorer,
        path: entry.path,
      );
  }
}
