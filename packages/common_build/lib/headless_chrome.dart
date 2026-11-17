/// Headless Chrome driven through the DevTools protocol, with a local static
/// site server: open a page, evaluate scripts, watch its events (a crash
/// included), capture screenshots. Dart VM only.
///
/// [HeadlessChrome] starts Chrome in a temporary profile, [CdpSession] talks
/// to a page, [StaticSiteServer] serves a build folder on a free local port.
library;

export 'src/headless_chrome.dart'
    show
        ScreenshotView,
        screenshotDesktop,
        screenshotMobile,
        screenshotDesktopDark,
        CdpException,
        CdpEvent,
        CdpSession,
        findChromeExecutable,
        HeadlessChrome,
        PageScreenshotter,
        pngSize;
export 'src/static_site_server.dart'
    show StaticSiteServer, staticSiteFileOfPath;
