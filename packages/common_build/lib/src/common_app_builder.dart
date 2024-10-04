import 'package:tekartik_common_build/version_io.dart' as version_io;

/// Common app builder
abstract class CommonAppBuilder {
  /// Path
  String get path;
}

/// Common app builder extension
extension CommonAppBuilderExt on CommonAppBuilder {
  /// Generate the version
  Future<void> generateVersion() async {
    await version_io.generateVersion(path: path);
  }
}
