## 0.1.3

- `jaspr_screenshot.dart`: the screens of a Flutter web app,
  `captureFlutterWebScreenshots` (a build served as a single page app, or a
  deployed app; each page in its language through `navigator.languages`) and
  `FlutterWebScreenshotter` (real time: the `flutter-view`, the
  tekartik_web_splash splash hidden, then a settle time);
  `headlessChromeFlutterArguments` (swiftshader, else CanvasKit stays white).
- `StaticSiteServer.start(spa: true)`: the unknown paths without an extension
  serve `index.html` (the path url strategy, as the Hosting rewrite).
- `captureSiteScreenshots(url:)`: a site served elsewhere (a server, a
  deployed site) instead of a built folder; the shared pieces
  `captureScreenshotFiles`, `withScreenshotSite`, `screenshotPageUrl` (a
  page path with its query).

## 0.1.2

- `jaspr_screenshot.dart`: screenshots of a built site with headless Chrome
  (DevTools protocol), moved from the tekartik.com site tools:
  `jasprSiteScreenshots` (every page of a build, each language, desktop and
  phone), `captureSiteScreenshots`, `jasprBuildScreenshotPages`, and the
  pieces (`StaticSiteServer`, `HeadlessChrome`, `PageScreenshotter`,
  `CdpSession`, `ScreenshotView`). Needs process_run 1.4.0.

## 0.1.1

- i18n: the default language pages are copied to `i18n/<default>/` too.
  Firebase Hosting serves the first language of the browser that has an i18n
  folder, so without them a browser asking for English then French got
  French (the Hosting emulator does not behave so, Hosting does).
- i18n: the pages are sent with `max-age=0, s-maxage=300`: a browser must
  revalidate them after a language switch (its cache ignores the language
  cookie), the CDN keeps caching them.
- Checks: every default language page has its `i18n/<default>/` copy; the
  canonical and hreflang links of the 404 pages are not followed.

## 0.1.0

- Initial version, extracted from the site tools of sondelio, buzzerelio and
  chordelio: `JasprSite` (build, post build steps, check, deploy, serve),
  `JasprSiteFlavor`, `firebase.json` from the flavors, i18n copies for
  Firebase Hosting language rewrites, `jasprSiteCheck`, `pubspecVersion`,
  `webpConvert` and a console menu (`jaspr_build_menu.dart`).
