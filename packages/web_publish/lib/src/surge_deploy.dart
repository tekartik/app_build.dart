import 'dart:io';

import 'package:process_run/shell.dart';
import 'package:tekartik_web_publish/src/deploy_common.dart';

/// Deploys a built web app to [Surge](https://surge.sh) via the `surge`
/// CLI.
class SurgeWebAppDeployer implements WebAppDeployer {
  /// Default local directory to deploy, used when [deploy] is called
  /// without its own `path`. If both are `null`, [deploy] throws.
  final String? path;

  /// Options identifying the Surge domain to deploy to.
  final SurgeWebAppDeployOptions options;

  /// Creates a deployer for [options], with a default local [path]
  /// (optional; can instead be passed per-call to [deploy]).
  SurgeWebAppDeployer({this.path, required this.options});

  /// Runs `surge . --domain <domain>` in [path] (falling back to this
  /// deployer's own [SurgeWebAppDeployer.path] if [path] is omitted) to
  /// publish it to [options]' Surge domain.
  ///
  /// Throws a [StateError] if neither [path] nor
  /// [SurgeWebAppDeployer.path] is set.
  @override
  Future<void> deploy({String? path}) async {
    var deployPath = this.path ?? path;
    if (deployPath == null) {
      throw StateError('Missing deploy path');
    }
    await Shell().cd(deployPath).run('surge . --domain ${options.domain}');
    stdout.writeln('Deployed to https://${options.domain}');
  }
}
