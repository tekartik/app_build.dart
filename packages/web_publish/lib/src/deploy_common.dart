import 'package:path/path.dart';

/// Base type for options passed to a [WebAppDeployer], e.g.
/// [SurgeWebAppDeployOptions].
abstract class WebAppDeployOptions {
  /// Creates deploy options. This base type carries no options of its own.
  WebAppDeployOptions();
}

/// Deploys a built web app from a local directory to a hosting target
/// (e.g. Surge, via `SurgeWebAppDeployer`).
abstract class WebAppDeployer {
  /// Deploys the contents of [path] (defaults to the deployer's own
  /// default directory) to the hosting target.
  Future<void> deploy({String? path});

  /// Creates a no-op deployer that does nothing when [deploy] is called.
  /// Useful as a default when no real deploy target is configured.
  factory WebAppDeployer() {
    return _WebAppDeployer();
  }
}

class _WebAppDeployer implements WebAppDeployer {
  @override
  Future<void> deploy({String? path}) async {
    // no deploy
  }
}

/// Default local directory for Surge deploys: `deploy/surge`.
final surgeWebAppDeployDirDefault = join('deploy', 'surge');

/// Default local directory for Firebase deploys: `deploy/firebase`.
final firebaseWebAppDeployDirDefault = join('deploy', 'firebase');

/// Default local directory a built web app is copied to before deploy:
/// `deploy/web`.
final webAppDeployDirDefault = join('deploy', 'web');

/// Default local port used when serving a built web app: `8080`.
final webAppServeWebPortDefault = 8080;

/// Options for deploying to [Surge](https://surge.sh) via
/// `SurgeWebAppDeployer`.
class SurgeWebAppDeployOptions implements WebAppDeployOptions {
  /// Surge domain to deploy to (e.g. `'my-app.surge.sh'`).
  final String domain;

  /// Creates Surge deploy options targeting [domain].
  SurgeWebAppDeployOptions({required this.domain});
}
