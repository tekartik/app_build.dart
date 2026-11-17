/// Screenshots with headless Chrome: the pages of a static site (served
/// locally with [StaticSiteServer] or deployed) and the screens of a Flutter
/// web app, in the views of `headless_chrome.dart`. Dart VM only.
library;

export 'headless_chrome.dart';
export 'src/flutter_web_screenshots.dart'
    show
        headlessChromeFlutterArguments,
        flutterWebSplashHidden,
        FlutterWebScreenshotter,
        captureFlutterWebScreenshots;
export 'src/site_screenshots.dart'
    show
        SiteScreenshotPage,
        htmlLang,
        captureSiteScreenshots,
        screenshotPageUrl,
        withScreenshotSite,
        captureScreenshotFiles;
