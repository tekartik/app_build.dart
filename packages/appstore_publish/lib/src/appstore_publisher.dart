import 'package:process_run/process_run.dart';

/// App Store Connect API credentials
abstract class AppStoreCredentials {}

/// User/password credential
class AppStoreCredentialsUserPassword implements AppStoreCredentials {
  /// Username
  final String username;

  /// Password
  final String password;

  /// Create a user/password credential
  AppStoreCredentialsUserPassword({
    required this.username,
    required this.password,
  });
}

/// API key/issuer id credential
class AppStoreCredentialsApiKeyIssuerId implements AppStoreCredentials {
  /// API key
  final String apiKey;

  /// Issuer id
  final String issuerId;

  /// Create an api key/issuer id credential
  AppStoreCredentialsApiKeyIssuerId({
    required this.apiKey,
    required this.issuerId,
  });
}

/// Publisher for App Store Connect API
class AppStorePublisher {
  /// AppStoreCredentials
  late final AppStoreCredentials credentials;

  /// App manager issuer id
  @Deprecated('Use credentials instead')
  final String? issuerId;

  /// App manager api key
  @Deprecated('Use credentials instead')
  final String? apiKey;

  /// Project path
  final String? path;

  late final _shell = Shell(workingDirectory: path);

  /// Create a publisher
  AppStorePublisher({
    /// Required
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

  /// Create a copy with modified fields
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

  /// Typically in build/ios/ipa/xxx.ipa
  Future<void> validateIosApp({required String ipaPath}) async {
    await _shell.run(
      'xcrun altool --validate-app -f ${shellArgument(ipaPath)} -t ios${_credentialsArgs()}',
    );
  }

  /// Upload ios app to TestFlight.
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

  /// Validate and upload ios app to TestFlight.
  Future<void> validateAndUploadIosApp({required String ipaPath}) async {
    await validateIosApp(ipaPath: ipaPath);
    await uploadIosApp(ipaPath: ipaPath);
  }

  /// Kill validate or upload task
  bool kill() {
    return _shell.kill();
  }
}
