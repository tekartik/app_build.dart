import 'package:tekartik_firebase_build/firebase_deploy.dart';

/// One Firebase Hosting target of a jaspr static site: where a build goes
/// and the urls its pages carry.
class JasprSiteFlavor {
  /// The hosting target in `firebase.json` (`dev`, `staging`, `prod`...).
  final String target;

  /// The Firebase project of the Hosting site.
  final String projectId;

  /// The Firebase Hosting site id.
  final String hostingId;

  /// The public base url, without trailing slash: canonical links,
  /// hreflang, sitemap and robots.txt.
  final String url;

  /// Search engines are told to stay away: noindex pages (the site's own
  /// code, from the `<PREFIX>_SITE_NOINDEX` define), `Disallow: /` in
  /// robots.txt and the `X-Robots-Tag` header.
  final bool noIndex;

  /// Extra `--dart-define`s of this flavor, by full name
  /// (`{'MYAPP_WEB_APP_URL': 'https://myapp.web.app'}`).
  final Map<String, String> defines;

  /// A flavor.
  const JasprSiteFlavor({
    required this.target,
    required this.projectId,
    required this.hostingId,
    required this.url,
    required this.noIndex,
    this.defines = const {},
  });

  /// The options of the Firebase deploy and serve commands.
  FirebaseDeployOptions get deployOptions => FirebaseDeployOptions(
    projectId: projectId,
    hostingId: hostingId,
    target: target,
  );

  @override
  String toString() => '$target ($url)';
}

/// The site's own Firebase Hosting rules, added to every target of
/// `firebase.json`, as written there.
class JasprSiteHosting {
  /// Header rules, after the common ones
  /// (`{'source': '/audio/**', 'headers': [{'key': ..., 'value': ...}]}`).
  final List<Map<String, Object?>> headers;

  /// Redirect rules
  /// (`{'source': '/old/', 'destination': '/new/', 'type': 301}`).
  final List<Map<String, Object?>> redirects;

  /// Site specific rules.
  const JasprSiteHosting({this.headers = const [], this.redirects = const []});
}
