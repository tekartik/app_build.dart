import 'dart:io';

import 'package:dev_build/shell.dart';

/// Lets callers observe and cancel the shell used to run a Flutter build
/// command, when passed to [FlutterWebAppBuilder.controller].
class BuildShellController {
  /// Creates a controller, optionally already wrapping [shell].
  BuildShellController({Shell? shell}) {
    _shell = shell;
  }

  /// The currently running command's shell.
  ///
  /// Throws if no shell has been set yet (before a command starts, or
  /// after this controller was created without one).
  Shell get shell => _shell!;
  Shell? _shell;

  /// Kills the current shell's process with `SIGKILL`, if one is set.
  void cancel() {
    _shell?.kill(ProcessSignal.sigkill);
  }
}

/// Private extension to set the shell
extension BuildShellControllerPrvExt on BuildShellController {
  set shell(Shell shell) {
    _shell = shell;
  }
}
