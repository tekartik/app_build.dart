import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:tekartik_firebase_build/firebase_deploy.dart';

import 'build_steps.dart';
import 'hosting_config.dart';
import 'jaspr_site_flavor.dart';
import 'site_check.dart';

/// A jaspr static site package (jaspr `mode: static`, `jaspr_cli` among its
/// dev dependencies) deployed to Firebase Hosting, one target per flavor.
///
/// The site reads `<definePrefix>_SITE_URL`, `<definePrefix>_SITE_NOINDEX`
/// and, with [appVersion], `<definePrefix>_APP_VERSION` from
/// `String.fromEnvironment` / `bool.fromEnvironment`.
class JasprSite {
  /// The site package, absolute or relative to the current directory.
  final String path;

  /// The prefix of the `--dart-define`s (`MYAPP` gives `MYAPP_SITE_URL`).
  final String definePrefix;

  /// The Hosting targets, `dev` first by convention.
  final List<JasprSiteFlavor> flavors;

  /// The version of the app the site describes, passed as
  /// `<definePrefix>_APP_VERSION` (see [pubspecVersion]).
  final String Function()? appVersion;

  /// The languages of the site, the default one first (at the root), the
  /// others under `/<language>/` and served by browser language through
  /// Firebase Hosting i18n rewrites.
  final List<String> languages;

  /// Url paths (regular expressions) left out of the sitemap, on top of the
  /// 404 pages (`^/404`, `^/<language>/404`).
  final List<String> sitemapExclude;

  /// Url paths (regular expressions) of default language pages that have
  /// no version in the other languages, for [check].
  final List<String> monolingualPaths;

  /// The site's own Hosting headers and redirects.
  final JasprSiteHosting hosting;

  /// A site.
  const JasprSite({
    required this.path,
    required this.definePrefix,
    required this.flavors,
    this.appVersion,
    this.languages = const ['en', 'fr'],
    this.sitemapExclude = const [],
    this.monolingualPaths = const [],
    this.hosting = const JasprSiteHosting(),
  });

  /// The site package, absolute.
  String get sitePath => normalize(absolute(path));

  /// `build/jaspr`, where `jaspr build` writes.
  String get buildPath => join(sitePath, 'build', 'jaspr');

  /// `deploy/firebase/hosting`: `firebase.json`, `.firebaserc` and the
  /// `public` copy of the last build deployed or served.
  String get hostingPath => join(sitePath, 'deploy', 'firebase', 'hosting');

  /// The languages after the default one.
  List<String> get otherLanguages => languages.skip(1).toList();

  /// The flavor of [target].
  JasprSiteFlavor flavor(String target) => flavors.firstWhere(
    (flavor) => flavor.target == target,
    orElse: () => throw ArgumentError.value(target, 'target', 'unknown'),
  );

  /// The `--dart-define`s of a build for [flavor].
  Map<String, String> definesFor(JasprSiteFlavor flavor) => {
    '${definePrefix}_SITE_URL': flavor.url,
    '${definePrefix}_SITE_NOINDEX': '${flavor.noIndex}',
    if (appVersion != null) '${definePrefix}_APP_VERSION': appVersion!(),
    ...flavor.defines,
  };

  /// The `--sitemap-exclude` pattern (jaspr takes one).
  String get sitemapExcludePattern {
    var patterns = [
      '^/404',
      for (var language in otherLanguages) '^/$language/404',
      ...sitemapExclude,
    ];
    return patterns.length == 1 ? patterns.first : patterns.join('|');
  }

  /// The arguments of `jaspr build` for [flavor].
  List<String> buildArguments(JasprSiteFlavor flavor) => [
    '--sitemap-domain',
    flavor.url,
    '--sitemap-exclude',
    sitemapExcludePattern,
    for (var MapEntry(:key, :value) in definesFor(flavor).entries)
      '--dart-define=$key=$value',
  ];

  /// `dart pub get`, `jaspr build` for [flavor], then [postBuild].
  Future<void> build(JasprSiteFlavor flavor) async {
    var shell = Shell(workingDirectory: sitePath);
    await shell.run('dart pub get');
    await shell.run(
      'dart run jaspr_cli:jaspr build ${shellArguments(buildArguments(flavor))}',
    );
    await postBuild(flavor);
  }

  /// What `jaspr build` leaves to do, on the build of [flavor]: the target
  /// marker, robots.txt, the 404 pages moved where Hosting serves them, the
  /// build_runner leftovers deleted, the sitemap trailing slashes and the
  /// i18n copies of the other languages.
  Future<void> postBuild(JasprSiteFlavor flavor) async {
    await jasprBuildWriteTargetMarker(buildPath, flavor.target);
    await jasprBuildWriteRobots(
      buildPath,
      url: flavor.url,
      noIndex: flavor.noIndex,
    );
    await jasprBuildMove404(buildPath, otherLanguages: otherLanguages);
    await jasprBuildRemoveLeftovers(buildPath);
    await jasprBuildSitemapTrailingSlash(buildPath);
    for (var language in otherLanguages) {
      await jasprBuildI18nCopies(
        buildPath,
        language: language,
        languages: otherLanguages,
      );
    }
  }

  /// The `firebase.json` of the site.
  Map<String, Object?> get firebaseJson => jasprSiteFirebaseJson(
    flavors,
    i18n: otherLanguages.isNotEmpty,
    hosting: hosting,
  );

  /// Writes `firebase.json` in [hostingPath].
  Future<void> writeFirebaseJson() =>
      jasprSiteWriteFirebaseJson(hostingPath, firebaseJson);

  /// Checks the last build, which must be the one of [flavor]
  /// ([jasprSiteCheck]).
  Future<JasprSiteCheckResult> check(
    JasprSiteFlavor flavor, {
    bool external = false,
  }) {
    jasprBuildCheckTargetMarker(buildPath, flavor.target);
    return jasprSiteCheck(
      buildPath,
      url: flavor.url,
      noIndex: flavor.noIndex,
      languages: languages,
      monolingualPaths: monolingualPaths,
      external: external,
    );
  }

  /// Checks the last build of [flavor] (unless [check] is false), writes
  /// `firebase.json` and copies the build to the hosting `public` folder
  /// (emptied first: no file of a previous build survives).
  Future<void> copyToHosting(
    JasprSiteFlavor flavor, {
    bool check = true,
  }) async {
    jasprBuildCheckTargetMarker(buildPath, flavor.target);
    if (check) {
      var result = await this.check(flavor);
      if (!result.ok) {
        throw StateError('${flavor.target} build: $result');
      }
    }
    await writeFirebaseJson();
    var publicDir = Directory(join(hostingPath, 'public'));
    if (publicDir.existsSync()) {
      await publicDir.delete(recursive: true);
    }
    await firebaseWebAppBuildToDeploy(sitePath, folder: 'jaspr');
  }

  /// Deploys the last build of [flavor] ([build]): its urls, noindex flag
  /// and defines are in the pages.
  Future<void> deploy(JasprSiteFlavor flavor, {bool check = true}) async {
    await copyToHosting(flavor, check: check);
    await firebaseWebAppDeploy(sitePath, flavor.deployOptions);
  }

  /// [build] then [deploy].
  Future<void> buildAndDeploy(JasprSiteFlavor flavor) async {
    await build(flavor);
    await deploy(flavor);
  }

  /// Serves the last build of [flavor] with the Firebase Hosting emulator:
  /// the headers, the redirects, the i18n rewrites and the 404 pages as
  /// Hosting serves them.
  Future<void> serve(JasprSiteFlavor flavor, {bool check = true}) async {
    await copyToHosting(flavor, check: check);
    await firebaseWebAppServe(sitePath, flavor.deployOptions);
  }
}
