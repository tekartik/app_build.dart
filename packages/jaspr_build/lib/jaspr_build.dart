/// Build, check and deploy jaspr static sites to Firebase Hosting.
///
/// The site package runs `jaspr build` itself (its own `jaspr_cli`); this
/// library never imports jaspr.
library;

export 'src/build_steps.dart'
    show
        jasprSiteTargetFileName,
        jasprSiteI18nFolder,
        jasprBuildLeftovers,
        jasprBuildWriteTargetMarker,
        jasprBuildReadTargetMarker,
        jasprBuildCheckTargetMarker,
        jasprBuildWriteRobots,
        jasprBuildMove404,
        jasprBuildRemoveLeftovers,
        jasprBuildSitemapTrailingSlash,
        jasprBuildI18nCopies,
        jasprBuildI18nDefaultCopies;
export 'src/hosting_config.dart'
    show jasprSiteFirebaseJson, jasprSiteWriteFirebaseJson;
export 'src/jaspr_site.dart' show JasprSite;
export 'src/jaspr_site_flavor.dart' show JasprSiteFlavor, JasprSiteHosting;
export 'src/pubspec_version.dart' show pubspecVersion;
export 'src/site_check.dart' show JasprSiteCheckResult, jasprSiteCheck;
export 'src/webp.dart' show webpConvert;
