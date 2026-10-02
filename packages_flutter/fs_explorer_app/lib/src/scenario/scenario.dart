import 'dart:async';

import 'package:festenao_common/fs/file_system_explorer.dart';
import 'package:flutter/foundation.dart';

/// How loud a line of the scenario log is.
enum FsScenarioLogLevel {
  /// What the scenario is about to do, or did.
  info,

  /// A write that went through: a file created, a record added.
  action,

  /// Something the scenario noticed and went on from: a directory gone.
  warning,

  /// A step that failed, the scenario going on with the next one.
  error,

  /// The scenario ended, one way or another.
  done,
}

/// One line of the scenario log, what the left pane lists.
class FsScenarioLogEntry {
  /// When it was logged.
  final DateTime time;

  /// What it says.
  final String message;

  /// How loud it is.
  final FsScenarioLogLevel level;

  /// Entry [message] at [level], now.
  FsScenarioLogEntry(this.message, {this.level = FsScenarioLogLevel.info})
    : time = DateTime.now();

  @override
  String toString() => '[${level.name}] $message';
}

/// How far a scenario is: [done] steps of [total].
class FsScenarioProgress {
  /// Steps done.
  final int done;

  /// Steps in all.
  final int total;

  /// Progress [done] of [total].
  const FsScenarioProgress(this.done, this.total);

  /// 0 to 1.
  double get ratio => total == 0 ? 0 : done / total;

  @override
  String toString() => '$done/$total';
}

/// What a running scenario gets: a sandboxed explorer of its own directory,
/// a log, a clock and a way to tell whether it was stopped.
///
/// A scenario is written to survive whatever the user does to the storage
/// meanwhile — clearing the site data in the browser, deleting the folder on
/// the disk, the "Clear data" button of the app: [attempt] turns a failed step
/// into a log line and [ensureDirectory] makes its directory again before a
/// write.
class FsScenarioContext {
  final FsScenarioRunner _runner;

  /// The directory of the scenario, sandboxed: paths cannot leave it.
  final FileSystemExplorer explorer;

  /// How long a step waits, a second in the app, far less in a test.
  final Duration tick;

  FsScenarioContext._(this._runner, this.explorer, this.tick);

  /// True once the user stopped the scenario: a scenario checks it after
  /// every [wait] and returns.
  bool get isCancelled => _runner._cancelled;

  /// Logs [message].
  void log(
    String message, {
    FsScenarioLogLevel level = FsScenarioLogLevel.info,
  }) => _runner._log(message, level: level);

  /// Logs a write that went through.
  void action(String message) => log(message, level: FsScenarioLogLevel.action);

  /// Logs something noticed.
  void warn(String message) => log(message, level: FsScenarioLogLevel.warning);

  /// Reports [done] steps of [total], the pane drawing it as a bar.
  void progress(int done, int total) =>
      _runner._progress(FsScenarioProgress(done, total));

  /// Tells the tree that the file system changed.
  void changed() => _runner._changed();

  /// Runs [action], logging what it threw instead of throwing it: null when
  /// it failed. The scenario goes on with its next step.
  Future<T?> attempt<T>(String what, Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      _runner._failures++;
      log('$what failed: $e', level: FsScenarioLogLevel.error);
      return null;
    }
  }

  /// Waits [duration], a [tick] by default; false when the scenario was
  /// stopped meanwhile — the scenario then returns.
  Future<bool> wait([Duration? duration]) async {
    if (isCancelled) {
      return false;
    }
    final completer = Completer<void>();
    final timer = Timer(duration ?? tick, completer.complete);
    _runner._wakeUp = () {
      timer.cancel();
      if (!completer.isCompleted) {
        completer.complete();
      }
    };
    await completer.future;
    _runner._wakeUp = null;
    return !isCancelled;
  }

  /// Makes the directory [path] of the scenario, the root by default, when it
  /// is not there — the storage may have been cleared since the last step.
  ///
  /// True when it had to be made again.
  Future<bool> ensureDirectory([String path = '']) async {
    if (await explorer.entry(path) != null) {
      return false;
    }
    await explorer.createDirectory(path);
    return true;
  }
}

/// What a scenario runs through, step by step, in a directory of its own.
///
/// [run] gets the directory empty when it starts; whatever it leaves is what
/// the tree shows afterwards, until "Clear data".
abstract class FsScenario {
  /// Names the directory of the scenario, `create_file_every_second`.
  String get id;

  /// What the picker displays.
  String get title;

  /// What the scenario does, in a sentence or two.
  String get description;

  /// Runs the scenario in [context], returning when done or stopped.
  Future<void> run(FsScenarioContext context);

  @override
  String toString() => id;
}

/// Where a runner is.
enum FsScenarioState {
  /// Nothing running yet, or the last run cleared.
  idle,

  /// A scenario is running.
  running,

  /// The last scenario ran to its end.
  done,

  /// The last scenario was stopped by the user.
  stopped,

  /// The last scenario threw out of [FsScenario.run] itself.
  failed,
}

/// Runs one scenario at a time in a directory of a [FileSystemExplorer] and
/// keeps its log, what the scenario screen listens to.
///
/// [explorer] is the scenarios directory of the app, sandboxed; each scenario
/// gets `explorer.sub(scenario.id)`. [clear] deletes everything in it, the
/// "Clear data" of the app, allowed while a scenario runs: the scenario
/// notices and goes on.
class FsScenarioRunner extends ChangeNotifier {
  /// The scenarios directory, every scenario in a sub directory of its own.
  final FileSystemExplorer explorer;

  /// How long a scenario step waits.
  final Duration tick;

  /// Bumped whenever the file system changed, what the tree refreshes on.
  final changes = ValueNotifier<int>(0);

  FsScenario? _scenario;
  var _state = FsScenarioState.idle;
  final _entries = <FsScenarioLogEntry>[];
  FsScenarioProgress? _progressValue;
  var _cancelled = false;
  var _failures = 0;
  void Function()? _wakeUp;
  Future<void>? _running;

  /// Runner in [explorer], a step every [tick].
  FsScenarioRunner({
    required this.explorer,
    this.tick = const Duration(seconds: 1),
  });

  /// Where the scenarios directory really is, below the sandbox: what a
  /// screen shows the user, who may go and delete it.
  String get nativePath => explorer.nativePath('');

  /// The scenario running, or the last one run.
  FsScenario? get scenario => _scenario;

  /// Where the runner is.
  FsScenarioState get state => _state;

  /// True while a scenario runs.
  bool get isRunning => _state == FsScenarioState.running;

  /// The log, oldest first.
  List<FsScenarioLogEntry> get entries => List.unmodifiable(_entries);

  /// How far the running scenario is, null when it did not say.
  FsScenarioProgress? get progress => _progressValue;

  /// How many steps failed in the last run.
  int get failures => _failures;

  void _log(
    String message, {
    FsScenarioLogLevel level = FsScenarioLogLevel.info,
  }) {
    _entries.add(FsScenarioLogEntry(message, level: level));
    notifyListeners();
  }

  void _progress(FsScenarioProgress progress) {
    _progressValue = progress;
    notifyListeners();
  }

  void _changed() {
    changes.value++;
  }

  /// Starts [scenario], the log cleared, and returns when it is over.
  ///
  /// Throws a [StateError] when one is already running.
  Future<void> start(FsScenario scenario) {
    if (isRunning) {
      throw StateError('${_scenario?.id} is already running');
    }
    _scenario = scenario;
    _state = FsScenarioState.running;
    _entries.clear();
    _progressValue = null;
    _cancelled = false;
    _failures = 0;
    notifyListeners();
    final future = _running = _run(scenario);
    return future;
  }

  Future<void> _run(FsScenario scenario) async {
    final context = FsScenarioContext._(this, explorer.sub(scenario.id), tick);
    _log('Starting "${scenario.title}" in ${scenario.id}/');
    try {
      await context.attempt('Preparing ${scenario.id}/', () async {
        await explorer.delete(scenario.id);
        await explorer.createDirectory(scenario.id);
      });
      _changed();
      await scenario.run(context);
      if (_cancelled) {
        _state = FsScenarioState.stopped;
        _log('Stopped', level: FsScenarioLogLevel.done);
      } else {
        _state = FsScenarioState.done;
        _log(
          _failures == 0
              ? 'Done, every step went through'
              : 'Done, $_failures step${_failures == 1 ? '' : 's'} failed',
          level: FsScenarioLogLevel.done,
        );
      }
    } catch (e) {
      _state = FsScenarioState.failed;
      _log('Failed: $e', level: FsScenarioLogLevel.error);
    } finally {
      _running = null;
      _changed();
      notifyListeners();
    }
  }

  /// Stops the running scenario, at its next wait, and returns once it is
  /// over.
  Future<void> stop() async {
    if (!isRunning) {
      return;
    }
    _cancelled = true;
    _log('Stopping…');
    _wakeUp?.call();
    await _running;
  }

  /// Deletes everything in the scenarios directory, running scenario or not —
  /// the "Clear data" of the app, what the browser does to the site data.
  Future<void> clear() async {
    final entries = await explorer.list();
    for (final entry in entries) {
      await explorer.delete(entry.path);
    }
    _changed();
    _log(
      entries.isEmpty
          ? 'Cleared: nothing was there'
          : 'Cleared ${entries.length} entr${entries.length == 1 ? 'y' : 'ies'} '
                'of $nativePath',
      level: FsScenarioLogLevel.warning,
    );
  }

  @override
  void dispose() {
    _cancelled = true;
    _wakeUp?.call();
    changes.dispose();
    super.dispose();
  }
}
