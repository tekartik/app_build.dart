import 'package:dev_build/build_support.dart';
import 'package:process_run/shell.dart';
import 'package:process_run/stdio.dart';

/// Default local port used by [ServeDirOptions] when none is specified.
const serveDirPortDefault = 8080;

/// Options for serving a local directory over HTTP, via [DirServeBuilder].
class ServeDirOptions {
  /// Local directory to serve.
  final String path;

  /// Local port to serve on, defaults to [serveDirPortDefault].
  final int port;

  /// When `true`, serves with `Cross-Origin-Embedder-Policy: credentialless`
  /// and `Cross-Origin-Opener-Policy: same-origin`, the cross-origin
  /// isolation headers needed by WASM builds using threads /
  /// `SharedArrayBuffer`.
  final bool secure;

  /// Creates options to serve [path] on [port] (defaults to
  /// [serveDirPortDefault]), with [secure] cross-origin isolation headers
  /// off by default.
  ServeDirOptions({required this.path, int? port, bool? secure})
    : port = port ?? serveDirPortDefault,
      secure = secure ?? false;
}

/// Serves a local directory over HTTP for the given [options], using
/// `dhttpd` (activating it first if needed) as the underlying server.
class DirServeBuilder {
  /// Options controlling what/how to serve.
  final ServeDirOptions options;

  /// If set, the shell command is run through this shell instead of a
  /// fresh [Shell].
  final Shell? shell;

  /// Creates a builder serving [options].
  DirServeBuilder(this.options, {this.shell});

  /// Serves [ServeDirOptions.path] on [ServeDirOptions.port], adding
  /// cross-origin isolation headers when [ServeDirOptions.secure] is set.
  Future<void> serve() async {
    await checkAndActivatePackage('dhttpd');
    stdout.writeln('http://localhost:${options.port}');
    var headersOptions = options.secure
        ? ' --headers=Cross-Origin-Embedder-Policy=credentialless;Cross-Origin-Opener-Policy=same-origin'
        : '';
    await (shell ?? Shell()).run(
      'dart pub global run dhttpd:dhttpd --path ${shellArgument(options.path)} --port ${options.port}$headersOptions',
    );
  }
}
