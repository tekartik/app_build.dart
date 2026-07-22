import 'package:tekartik_common_build/version_io.dart' as version_io;

/// Base type for a project builder rooted at a given [path], extended with
/// version-generation helpers by [CommonAppBuilderExt].
abstract class CommonAppBuilder {
  /// Root path of the project this builder operates on.
  String get path;
}

/// Version-generation operations available on any [CommonAppBuilder].
extension CommonAppBuilderExt on CommonAppBuilder {
  /// Generates the version file for the project at [CommonAppBuilder.path],
  /// via `version_io`'s `generateVersion`.
  Future<void> generateVersion() async {
    await version_io.generateVersion(path: path);
  }

  /// Generates the version file, but only if one was already generated
  /// before (i.e. skips projects that never opted in), checked via
  /// `version_io`'s `hasGeneratedVersionFile`.
  Future<void> generateVersionIfNeeded() async {
    if (await version_io.hasGeneratedVersionFile(path: path)) {
      await generateVersion();
    }
  }
}
