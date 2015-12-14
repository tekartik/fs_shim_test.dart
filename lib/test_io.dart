library fs_shim_test.test_io.dart;

export 'test.dart';
export 'context_io.dart';

import 'dart:mirrors';

///
/// Usage
///
/// <pre>
/// class TestScript extends Script {}
/// String get testScriptPath => getScriptPath(TestScript);
/// </pre>
///
String getScriptPath(Type type) =>
    (reflectClass(type).owner as LibraryMirror).uri.toFilePath();

abstract class Script {
  String get path => getScriptPath(this.runtimeType);
}
