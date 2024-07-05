import 'package:path/path.dart';

/// Web deploy options.
abstract class WebAppDeployOptions {}

/// Surge web app deployment.
final surgeWebAppDeployDirDefault = join('deploy', 'surge');

/// Firebase web app deployment.
final firebaseWebAppDeployDirDefault = join('deploy', 'firebase');

/// Surge web app deployment.
class SurgeWebAppDeployOptions implements WebAppDeployOptions {
  /// Domain (domain.surge.sh).
  final String domain;

  /// Constructor.
  SurgeWebAppDeployOptions({required this.domain});
}
