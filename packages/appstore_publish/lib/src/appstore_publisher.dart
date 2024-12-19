import 'package:process_run/process_run.dart';

/// App Store Connect API credentials
abstract class AppStoreCredentials {}

/// User/password credential
class AppStoreCredentialsUserPassword implements AppStoreCredentials {
  final String username;
  final String password;

  AppStoreCredentialsUserPassword(
      {required this.username, required this.password});
}

class AppStoreCredentialsApiKeyIssuerId implements AppStoreCredentials {
  final String apiKey;
  final String issuerId;

  AppStoreCredentialsApiKeyIssuerId(
      {required this.apiKey, required this.issuerId});
}

/// Publisher for App Store Connect API
class AppStorePublisher {
  /// AppStoreCredentials
  late final AppStoreCredentials credentials;

  /// App manager issuer id
  final String? issuerId;

  /// App manager api key
  final String? apiKey;

  /// Project path
  final String path;

  late final _shell = Shell(workingDirectory: path);

  /// Create a publisher
  AppStorePublisher(
      {AppStoreCredentials? credentials,
      // Compat
      this.issuerId,
      // Compat
      this.apiKey,
      required this.path}) {
    this.credentials = credentials ??
        AppStoreCredentialsApiKeyIssuerId(apiKey: apiKey!, issuerId: issuerId!);
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
        'xcrun altool --validate-app -f ${shellArgument(ipaPath)} -t ios${_credentialsArgs()}');
  }

  /// Upload ios app to TestFlight.
  Future<void> uploadIosApp({required String ipaPath}) async {
    await _shell.run(
        'xcrun altool --upload-app -f ${shellArgument(ipaPath)} -t ios${_credentialsArgs()}');
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
