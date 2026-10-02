import 'package:flutter/material.dart';

import 'file_system_choice.dart';
import 'screen/home_screen.dart';

/// The app: a home listing the file systems, each browsed as a tree or a
/// list and running scenarios.
///
/// The file systems are built once here, so what is written in the memory one
/// stays as long as the app runs.
class FsExplorerApp extends StatefulWidget {
  /// The file systems offered, [fsExplorerChoices] by default.
  final List<FsChoice>? choices;

  /// The app.
  const FsExplorerApp({super.key, this.choices});

  @override
  State<FsExplorerApp> createState() => _FsExplorerAppState();
}

class _FsExplorerAppState extends State<FsExplorerApp> {
  late final List<FsChoice> _choices = widget.choices ?? fsExplorerChoices();

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'fs_shim explorer',
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
      ),
    ),
    home: FsHomeScreen(choices: _choices),
  );
}
