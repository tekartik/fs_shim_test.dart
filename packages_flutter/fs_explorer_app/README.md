# fs_explorer_app

A Flutter app browsing the `fs_shim` file systems — memory, io, web — and
watching scenarios write to them.

The screens come from `festenao_common_flutter`'s file system explorer (the
list explorer, the text, hex and object editors, the demo documents and
databases) on top of two things of this package:

- a tree view (`FileSystemTreeController` / `FileSystemTreeView`) over a
  `FileSystemExplorer`, refreshed while something else writes;
- a scenario runner (`FsScenarioRunner`) and a few scenarios: a file every
  second for 30 seconds, a growing file, a tree built then torn down, records
  added to a sembast database.

## Screens

- Home: the file systems — memory (a scratch one, kept while the app runs), io
  on mobile and desktop, web (IndexedDB) in a browser, and the web engine over
  an in memory IndexedDB everywhere.
- File system: what it supports, the directories it can be browsed from (app
  data, documents, support, temporary, downloads, current directory…), each
  opening as a tree, or as a list from its trailing button, sandboxed.
- Scenarios: the log of what the scenario does on the left, the tree of the
  directory it writes to on the right (stacked on a narrow screen). Scenarios
  only write in `<support>/fs_explorer_app/scenarios/<scenario id>/`.

"Clear data" wipes the scenarios directory, running scenario or not, the way
clearing the site data in a browser does: a scenario reports what it lost and
goes on, making its directory again before the next write. On the web the
`fs_shim` IndexedDB file system opens a new connection when the browser closed
the old one, so clearing the site data from the devtools while a scenario runs
is handled the same way.

## Run

```sh
flutter run -d chrome
flutter run -d linux
```

## Local development

The dependencies are git ones; `tool/gen_overrides.py` writes a
`pubspec_overrides.yaml` (git ignored) mapping them to the local checkouts
under `~/tekartik/devx/git/github.com`:

```sh
python3 tool/gen_overrides.py
flutter pub get
```
