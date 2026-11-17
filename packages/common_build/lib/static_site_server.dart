/// A static file server on a free local port ([StaticSiteServer]): a build
/// folder served as a static host (Firebase Hosting) does. Dart VM only.
library;

export 'src/static_site_server.dart'
    show StaticSiteServer, staticSiteFileOfPath;
