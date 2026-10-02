import 'package:process_run/shell.dart';

/// Makes the `web/` folder again, from the flutter template.
Future<void> main() async {
  await run('flutter create --platforms web .');
}
