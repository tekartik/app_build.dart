import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:tekartik_common_build/common_app_builder.dart';

/// Identifies a flutter app and the firebase project it is configured
/// from, used by [FirebaseFlutterProjectBuilder].
class FirebaseFlutterProjectOptions {
  /// Firebase project id (`flutterfire configure --project`).
  final String projectId;

  /// Absolute, normalized path of the flutter app.
  late final String path;

  /// The platforms to generate firebase options for (`--platforms`, e.g.
  /// `['web']` or `['android', 'ios', 'web']`); every platform of the app
  /// when empty.
  final List<String> platforms;

  /// The generated dart file (`--out`), relative to [path]:
  /// [FirebaseFlutterProjectBuilder.defaultFirebaseOptionsFile] by default,
  /// typically one file per flavor (`lib/firebase_options_dev.dart`).
  final String firebaseOptionsFile;

  /// Options for [projectId], in the flutter app at [path] (the current
  /// directory by default).
  FirebaseFlutterProjectOptions({
    required this.projectId,
    String? path,
    this.platforms = const [],
    this.firebaseOptionsFile =
        FirebaseFlutterProjectBuilder.defaultFirebaseOptionsFile,
  }) {
    this.path = normalize(absolute(path ?? '.'));
  }

  /// Options for one [flavor] of the app: the generated file is
  /// `lib/firebase_options_<flavor>.dart`
  /// ([FirebaseFlutterProjectBuilder.flavorFirebaseOptionsFile]), from the
  /// firebase project of the flavor.
  factory FirebaseFlutterProjectOptions.flavor({
    required String projectId,
    required String flavor,
    String? path,
    List<String> platforms = const [],
  }) => FirebaseFlutterProjectOptions(
    projectId: projectId,
    path: path,
    platforms: platforms,
    firebaseOptionsFile:
        FirebaseFlutterProjectBuilder.flavorFirebaseOptionsFile(flavor),
  );

  /// A copy of these options, overriding the given fields.
  FirebaseFlutterProjectOptions copyWith({
    String? projectId,
    String? path,
    List<String>? platforms,
    String? firebaseOptionsFile,
  }) {
    return FirebaseFlutterProjectOptions(
      projectId: projectId ?? this.projectId,
      path: path ?? this.path,
      platforms: platforms ?? this.platforms,
      firebaseOptionsFile: firebaseOptionsFile ?? this.firebaseOptionsFile,
    );
  }

  @override
  String toString() =>
      'FirebaseFlutterProjectOptions($projectId, $firebaseOptionsFile, $path)';
}

/// A flutter app using firebase: runs the `flutterfire` cli on it, i.e.
/// generates its firebase options from the project described by [options].
///
/// Needs the flutterfire cli (`dart pub global activate flutterfire_cli`)
/// and a `firebase login` with access to the project. The apps of the
/// project (the web app, the android package...) must be registered on the
/// firebase project first, one per platform asked.
class FirebaseFlutterProjectBuilder implements CommonAppBuilder {
  /// The file `flutterfire configure` generates by default, relative to the
  /// flutter app.
  static const defaultFirebaseOptionsFile = 'lib/firebase_options.dart';

  /// The app and the project this builder targets.
  final FirebaseFlutterProjectOptions options;

  /// Absolute path of the flutter app, i.e. [FirebaseFlutterProjectOptions.path].
  @override
  String get path => options.path;

  /// Creates a builder for the app and the project described by [options].
  FirebaseFlutterProjectBuilder({required this.options});

  /// A builder for one [flavor] of the app at [path] (the current directory
  /// by default), generating `lib/firebase_options_<flavor>.dart` from the
  /// firebase project of the flavor, for [platforms] (every one when empty):
  ///
  /// ```dart
  /// await FirebaseFlutterProjectBuilder.flavor(
  ///   projectId: 'my-project-dev',
  ///   flavor: 'dev',
  ///   platforms: ['web'],
  /// ).configure();
  /// ```
  factory FirebaseFlutterProjectBuilder.flavor({
    required String projectId,
    required String flavor,
    String? path,
    List<String> platforms = const [],
  }) => FirebaseFlutterProjectBuilder(
    options: FirebaseFlutterProjectOptions.flavor(
      projectId: projectId,
      flavor: flavor,
      path: path,
      platforms: platforms,
    ),
  );

  /// The firebase options file of [flavor], relative to the app:
  /// `lib/firebase_options_<flavor>.dart`.
  static String flavorFirebaseOptionsFile(String flavor) =>
      'lib/firebase_options_$flavor.dart';

  /// The `flutterfire configure` command line [configure] runs.
  ///
  /// [overwrite] rewrites the generated file when it exists, for another
  /// project or other platforms (`--overwrite-firebase-options`); [yes]
  /// skips the confirmation prompts (`--yes`).
  String configureCommand({bool overwrite = true, bool yes = false}) {
    var sb = StringBuffer(
      'flutterfire configure --project=${options.projectId}',
    );
    if (options.platforms.isNotEmpty) {
      sb.write(' --platforms=${options.platforms.join(',')}');
    }
    sb.write(' --out=${shellArgument(options.firebaseOptionsFile)}');
    if (overwrite) {
      sb.write(' --overwrite-firebase-options');
    }
    if (yes) {
      sb.write(' --yes');
    }
    return sb.toString();
  }

  /// Generates the firebase options of the app from its project:
  /// `flutterfire configure` in the app folder, see [configureCommand] for
  /// [overwrite] and [yes].
  Future<void> configure({bool overwrite = true, bool yes = false}) async {
    var shell = Shell(workingDirectory: path);
    await shell.run(configureCommand(overwrite: overwrite, yes: yes));
  }
}
