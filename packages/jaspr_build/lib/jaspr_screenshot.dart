/// Screenshots of a built static site with headless Chrome (DevTools
/// protocol): every page of a jaspr build on a desktop and a phone
/// ([jasprSiteScreenshots]), or chosen pages and views
/// ([captureSiteScreenshots]), and the pieces they are made of (a local
/// server for the build, Chrome, a page capture).
///
/// Chrome is `CHROME_EXECUTABLE`, else Chrome or Chromium on the path.
library;

export 'src/cdp_screenshot.dart'
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
export 'src/site_screenshots.dart'
    show
        SiteScreenshotPage,
        jasprBuildScreenshotPages,
        captureSiteScreenshots,
        jasprSiteScreenshots;
