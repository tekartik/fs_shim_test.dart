import 'package:dev_build/package.dart';

/// Makes sure `dhttpd` is activated, for the local web servers of the
/// `clean_build_and_run_web_*` tools.
Future<void> checkOrPubActivateDhttpd() async {
  await checkOrPubActivateHostedPackage(
    'dhttpd',
    versionBoundaries: VersionBoundaries.lower(Version(4, 3, 0)),
  );
}
