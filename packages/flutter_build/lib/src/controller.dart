import 'dart:io';

import 'package:dev_build/shell.dart';

/// Shell controller
class BuildShellController {
  /// Constructor
  BuildShellController({Shell? shell}) {
    _shell = shell;
  }

  /// Shell
  Shell get shell => _shell!;
  Shell? _shell;

  /// Cancel current shell
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
