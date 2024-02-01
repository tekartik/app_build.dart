import 'package:process_run/process_run.dart';

/// Publisher for App Store Connect API
class AppStorePublisher {
  /// App manager issuer id
  final String issuerId;

  /// App manager api key
  final String apiKey;

  /// Project path
  final String path;

  late final _shell = Shell(workingDirectory: path);
  AppStorePublisher(
      {required this.issuerId, required this.apiKey, required this.path});

  /// Typically in build/ios/ipa/xxx.ipa
  Future<void> validateIosApp({required String ipaPath}) async {
    await _shell.run(
        'xcrun altool --validate-app -f ${shellArgument(ipaPath)} -t ios --apiKey $apiKey --apiIssuer $issuerId');
  }

  Future<void> uploadIosApp({required String ipaPath}) async {
    await _shell.run(
        'xcrun altool --upload-app -f ${shellArgument(ipaPath)} -t ios --apiKey $apiKey --apiIssuer $issuerId');
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
