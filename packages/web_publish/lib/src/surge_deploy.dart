import 'dart:io';

import 'package:process_run/shell.dart';
import 'package:tekartik_web_publish/src/deploy_common.dart';

/// Surge deployer
class SurgeWebAppDeployer implements WebAppDeployer {
  /// The deploy path
  final String? path;

  /// The deploy options.
  final SurgeWebAppDeployOptions options;

  /// Constructor.
  SurgeWebAppDeployer({this.path, required this.options});

  /// Deploy.
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
