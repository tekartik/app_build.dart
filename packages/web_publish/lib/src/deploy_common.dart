import 'package:path/path.dart';

/// Web deploy options.
abstract class WebAppDeployOptions {}

/// Common web app deployer
abstract class WebAppDeployer {
  /// Deploy.
  Future<void> deploy({String? path});
}

/// Surge web app deployment.
final surgeWebAppDeployDirDefault = join('deploy', 'surge');

/// Firebase web app deployment.
final firebaseWebAppDeployDirDefault = join('deploy', 'firebase');

/// Common web app deploy dir.
final webAppDeployDirDefault = join('deploy', 'web');

/// Common web app serve port.
final webAppServeWebPortDefault = 8080;

/// Surge web app deployment.
class SurgeWebAppDeployOptions implements WebAppDeployOptions {
  /// Domain (domain.surge.sh).
  final String domain;

  /// Constructor.
  SurgeWebAppDeployOptions({required this.domain});
}
