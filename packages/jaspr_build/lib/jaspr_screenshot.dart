/// Screenshots of a built static site with headless Chrome (DevTools
/// protocol): every page of a jaspr build on a desktop and a phone
/// ([jasprSiteScreenshots]), or chosen pages and views
/// ([captureSiteScreenshots]), the screens of a Flutter web app
/// ([captureFlutterWebScreenshots]), and the pieces they are made of (a
/// local server for the build, Chrome, a page capture).
///
/// Chrome is `CHROME_EXECUTABLE`, else Chrome or Chromium on the path.
library;

// From tekartik_common_build (headless_chrome.dart), exported as before.
export 'package:tekartik_common_build/headless_chrome.dart'
    show
        ScreenshotView,
        screenshotDesktop,
        screenshotMobile,
        screenshotDesktopDark,
        StaticSiteServer,
        CdpException,
        CdpEvent,
        CdpSession,
        findChromeExecutable,
        HeadlessChrome,
        PageScreenshotter,
        pngSize;
// From tekartik_common_build (site_screenshots.dart), exported as before.
export 'package:tekartik_common_build/site_screenshots.dart'
    show
        headlessChromeFlutterArguments,
        flutterWebSplashHidden,
        FlutterWebScreenshotter,
        captureFlutterWebScreenshots,
        SiteScreenshotPage,
        captureSiteScreenshots,
        screenshotPageUrl,
        withScreenshotSite,
        captureScreenshotFiles;
export 'src/site_screenshots.dart'
    show jasprBuildScreenshotPages, jasprSiteScreenshots;
