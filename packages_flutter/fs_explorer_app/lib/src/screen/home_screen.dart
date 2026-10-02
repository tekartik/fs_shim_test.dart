import 'package:festenao_common_flutter/file_system_explorer_flutter.dart';
import 'package:flutter/material.dart';

import '../file_system_choice.dart';
import 'file_system_screen.dart';

/// The home screen: the file systems the app offers.
class FsHomeScreen extends StatelessWidget {
  /// The file systems, see [fsExplorerChoices].
  final List<FsChoice> choices;

  /// Home of [choices].
  const FsHomeScreen({super.key, required this.choices});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('fs_shim explorer')),
    body: ListView(
      children: [
        const ExplorerSectionHeader(label: 'File systems'),
        for (final choice in choices)
          ListTile(
            leading: Icon(switch (choice.id) {
              'memory' => Icons.memory,
              'web' => Icons.language,
              'io' => Icons.storage,
              _ => Icons.dns_outlined,
            }),
            title: Row(
              children: [
                Flexible(child: Text(choice.name)),
                const SizedBox(width: 8),
                ExplorerChip(label: choice.fileSystem.name, monospace: true),
              ],
            ),
            subtitle: Text(choice.description),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => goToFsFileSystemScreen(context, choice: choice),
          ),
      ],
    ),
  );
}
