import 'package:tekartik_common_build/common_app_builder.dart';
import 'package:tekartik_firebase_tools_common/firebase_project.dart' as tools;

/// Runs `firebase` CLI deploy/serve commands for the project described by
/// [tools.FirebaseProjectBuilder.options].
///
/// The implementation lives in `tekartik_firebase_tools_common`; this subclass
/// only adds [CommonAppBuilder], so the version-generation helpers of
/// `CommonAppBuilderExt` (`generateVersion`, `generateVersionIfNeeded`) apply
/// to a firebase project like they do to every other builder of `app_build`.
class FirebaseProjectBuilder extends tools.FirebaseProjectBuilder
    implements CommonAppBuilder {
  /// Creates a builder for the project described by [options].
  FirebaseProjectBuilder({required super.options});
}
