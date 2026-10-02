/// Browsing the `fs_shim` file systems — memory, io, web — as a tree or a
/// list, and watching scenarios write to them.
///
/// The screens come from `festenao_common_flutter` (the list explorer, the
/// text, hex and object editors) on top of a tree view and a scenario runner
/// of this package.
library;

export 'src/app.dart' show FsExplorerApp;
export 'src/file_system_choice.dart'
    show
        FsChoice,
        fsExplorerAppDirectoryName,
        fsExplorerAppPackageName,
        fsExplorerChoices;
export 'src/scenario/scenario.dart'
    show
        FsScenario,
        FsScenarioContext,
        FsScenarioLogEntry,
        FsScenarioLogLevel,
        FsScenarioProgress,
        FsScenarioRunner,
        FsScenarioState;
export 'src/scenario/scenarios.dart'
    show
        CreateFileEverySecondScenario,
        GrowingFileScenario,
        SembastRecordsScenario,
        TreeChurnScenario,
        fsExplorerScenarios;
export 'src/screen/file_system_screen.dart'
    show FsFileSystemScreen, goToFsFileSystemScreen;
export 'src/screen/home_screen.dart' show FsHomeScreen;
export 'src/screen/open_entry.dart'
    show fsExplorerCreateActions, openFileSystemEntry;
export 'src/screen/scenario_screen.dart'
    show FsScenarioScreen, fsScenariosExplorer, goToFsScenarioScreen;
export 'src/screen/tree_screen.dart'
    show FileSystemTreeScreen, goToFileSystemTreeScreen;
export 'src/tree/file_system_tree.dart'
    show FileSystemTreeController, FileSystemTreeRow, FileSystemTreeView;
