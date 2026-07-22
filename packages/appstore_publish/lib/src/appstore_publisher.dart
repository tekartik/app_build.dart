import 'package:process_run/process_run.dart';

/// Base type for credentials accepted by [AppStorePublisher]. Use either
/// [AppStoreCredentialsUserPassword] or [AppStoreCredentialsApiKeyIssuerId].
abstract class AppStoreCredentials {}

/// Authenticates with an Apple ID username and app-specific password.
class AppStoreCredentialsUserPassword implements AppStoreCredentials {
  /// Apple ID username (email).
  final String username;

  /// App-specific password for [username].
  final String password;

  /// Creates credentials from an Apple ID [username] and [password].
  AppStoreCredentialsUserPassword({
    required this.username,
    required this.password,
  });
}

/// Authenticates with an App Store Connect API key.
class AppStoreCredentialsApiKeyIssuerId implements AppStoreCredentials {
  /// App Store Connect API key ID.
  final String apiKey;

  /// App Store Connect API issuer ID.
  final String issuerId;

  /// Creates credentials from an App Store Connect [apiKey] and its
  /// [issuerId].
  AppStoreCredentialsApiKeyIssuerId({
    required this.apiKey,
    required this.issuerId,
  });
}

/// Validates and uploads iOS apps to App Store Connect / TestFlight via
/// `xcrun altool`/`iTMSTransporter`.
class AppStorePublisher {
  /// Credentials used to authenticate all `xcrun` calls.
  late final AppStoreCredentials credentials;

  /// App Store Connect issuer ID.
  @Deprecated('Use credentials instead')
  final String? issuerId;

  /// App Store Connect API key.
  @Deprecated('Use credentials instead')
  final String? apiKey;

  /// Working directory the underlying shell commands run from, or `null`
  /// to use the current directory.
  final String? path;

  late final _shell = Shell(workingDirectory: path);

  /// Creates a publisher that authenticates with [credentials] and runs
  /// commands from [path] (defaults to the current directory).
  ///
  /// [issuerId] and [apiKey] are deprecated equivalents of
  /// [AppStoreCredentialsApiKeyIssuerId]; when [credentials] is omitted,
  /// both must be provided.
  AppStorePublisher({
    AppStoreCredentials? credentials,
    // Compat
    @Deprecated('Use credentials instead') this.issuerId,
    // Compat
    @Deprecated('Use credentials instead') this.apiKey,
    this.path,
  }) {
    this.credentials =
        credentials ??
        // ignore: deprecated_member_use_from_same_package
        AppStoreCredentialsApiKeyIssuerId(apiKey: apiKey!, issuerId: issuerId!);
  }

  /// Returns a copy of this publisher, overriding [credentials] and/or
  /// [path] while keeping the rest unchanged.
  AppStorePublisher copyWith({AppStoreCredentials? credentials, String? path}) {
    return AppStorePublisher(
      credentials: credentials ?? this.credentials,
      path: path ?? this.path,
    );
  }

  String _credentialsArgs() {
    var credentials = this.credentials;
    if (credentials is AppStoreCredentialsUserPassword) {
      return ' -u ${shellArgument(credentials.username)} -p ${shellArgument(credentials.password)}';
    } else if (credentials is AppStoreCredentialsApiKeyIssuerId) {
      return ' --apiKey ${shellArgument(credentials.apiKey)} --apiIssuer ${shellArgument(credentials.issuerId)}';
    }

    throw UnsupportedError('Unsupported credentials');
  }

  /// Validates the `.ipa` at [ipaPath] (typically under
  /// `build/ios/ipa/xxx.ipa`) via `xcrun altool --validate-app`, without
  /// uploading it. Throws if validation fails.
  Future<void> validateIosApp({required String ipaPath}) async {
    await _shell.run(
      'xcrun altool --validate-app -f ${shellArgument(ipaPath)} -t ios${_credentialsArgs()}',
    );
  }

  /// Uploads the `.ipa` at [ipaPath] to TestFlight.
  ///
  /// If [useTransporter] is `true`, uploads via `xcrun iTMSTransporter`
  /// instead of the default `xcrun altool --upload-app`. Throws if the
  /// upload fails.
  Future<void> uploadIosApp({
    required String ipaPath,
    bool? useTransporter,
  }) async {
    if (useTransporter == true) {
      // Use transporter
      await _shell.run(
        'xcrun iTMSTransporter -m upload '
        '${_credentialsArgs()}'
        ' -assetFile ${shellArgument(ipaPath)}',
      );
      return;
    } else {
      await _shell.run(
        'xcrun altool --upload-app'
        ' -f ${shellArgument(ipaPath)} -t ios${_credentialsArgs()}',
      );
    }
  }

  /// Runs [validateIosApp] followed by [uploadIosApp] for the `.ipa` at
  /// [ipaPath].
  Future<void> validateAndUploadIosApp({required String ipaPath}) async {
    await validateIosApp(ipaPath: ipaPath);

    await uploadIosApp(ipaPath: ipaPath);
  }

  /// Kills the in-progress `validateIosApp`/`uploadIosApp` shell command,
  /// if any.
  ///
  /// Returns `true` if a running process was killed, `false` otherwise.
  bool kill() {
    return _shell.kill();
  }
}
