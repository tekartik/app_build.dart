import 'dart:io';

import 'package:process_run/shell.dart';
import 'package:tekartik_web_publish/src/deploy_common.dart';

/// Surge deployer
class SurgeWebAppDeployer {
  /// The deploy path
  final String path;

  /// The deploy options.
  final SurgeWebAppDeployOptions options;

  /// Constructor.
  SurgeWebAppDeployer({required this.path, required this.options});

  /// Deploy.
  Future<void> deploy() async {
    await Shell().cd(path).run('surge . --domain ${options.domain}');
    stdout.writeln('Deployed to https://${options.domain}');
  }
}
