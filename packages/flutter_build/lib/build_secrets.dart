/// Checks that a client build (web, apk, app bundle, ipa) contains none of
/// the secrets held in server code.
library;

export 'src/build_secrets.dart'
    show
        BuildSecret,
        BuildSecretMatch,
        BuildSecretsFoundException,
        buildCheckNoSecrets,
        buildFindSecrets,
        buildSecretMinLength,
        buildSecretsArchiveExtensions;
