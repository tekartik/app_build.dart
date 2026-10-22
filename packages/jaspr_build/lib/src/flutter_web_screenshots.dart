/// Screenshots of a Flutter web app with headless Chrome: a build served as
/// a single page app (or a deployed one), the arguments CanvasKit needs to
/// draw without a GPU, the wait for the first frames behind the splash, the
/// language of each page.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'cdp_screenshot.dart';
import 'site_screenshots.dart';

/// The Chrome arguments a Flutter web app needs to draw in headless Chrome:
/// WebGL in software (swiftshader), else CanvasKit leaves the page white.
const headlessChromeFlutterArguments = [
  '--use-angle=swiftshader',
  '--enable-unsafe-swiftshader',
];

/// The default readiness of a Flutter web app, past its `flutter-view`: the
/// splash of tekartik_web_splash (`#app_splash.app-loading`) hidden, true
/// when the app has none.
const flutterWebSplashHidden =
    "!document.querySelector('#app_splash.app-loading')";

/// Captures the screens of a Flutter web app in one Chrome tab (started
/// with [headlessChromeFlutterArguments]).
class FlutterWebScreenshotter {
  /// The tab.
  final CdpSession page;

  String? _userAgent;
  String? _lang;

  FlutterWebScreenshotter._(this.page);

  /// Enables the page events [capture] waits for.
  static Future<FlutterWebScreenshotter> open(CdpSession page) async {
    await page.call('Page.enable');
    return FlutterWebScreenshotter._(page);
  }

  /// A png of the window showing [url] in [view], the browser in [lang]
  /// (`fr`: `navigator.languages`, which a Flutter app follows) when given.
  ///
  /// Real time, not virtual time: after the load, waits for the
  /// `flutter-view` and [ready] (a JavaScript expression,
  /// [flutterWebSplashHidden] by default), then [settle] (the first frames,
  /// the fonts, the transitions), [timeout] at most.
  Future<Uint8List> capture(
    Uri url,
    ScreenshotView view, {
    String? lang,
    String ready = flutterWebSplashHidden,
    Duration settle = const Duration(seconds: 2),
    Duration timeout = const Duration(seconds: 90),
  }) async {
    await page.call('Emulation.setDeviceMetricsOverride', {
      'width': view.width,
      'height': view.height,
      'deviceScaleFactor': view.scale,
      'mobile': view.mobile,
    });
    await page.call('Emulation.setEmulatedMedia', {
      'features': [
        {'name': 'prefers-color-scheme', 'value': view.dark ? 'dark' : 'light'},
      ],
    });
    if (lang != _lang) {
      _userAgent ??=
          (await page.call('Browser.getVersion'))['userAgent'] as String;
      await page.call('Network.setUserAgentOverride', {
        'userAgent': _userAgent,
        'acceptLanguage': ?lang,
      });
      _lang = lang;
    }
    var loaded = page.events.firstWhere(
      (event) => event.method == 'Page.loadEventFired',
    );
    await page.call('Page.navigate', {'url': url.toString()});
    await loaded.timeout(timeout);
    var end = DateTime.now().add(timeout);
    var expression = "!!document.querySelector('flutter-view') && ($ready)";
    while (await page.evaluate(expression) != true) {
      if (DateTime.now().isAfter(end)) {
        throw CdpException('$url: the app did not draw in $timeout');
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    await Future<void>.delayed(settle);
    var shot = await page.call('Page.captureScreenshot', {'format': 'png'});
    return base64Decode(shot['data'] as String);
  }
}

/// Captures [pages] of the Flutter web app built in [root] (served locally
/// as a single page app, see [StaticSiteServer]) or at [url], each in the
/// language of the page ([SiteScreenshotPage.lang]) and in each of [views]
/// (a phone by default), as `<out>/<page.name>_<view.name>.png`; returns
/// the files written.
///
/// [only] and [where] choose the files ([captureScreenshotFiles]), [ready]
/// and [settle] the wait ([FlutterWebScreenshotter.capture]). Chrome is
/// [findChromeExecutable].
Future<List<File>> captureFlutterWebScreenshots({
  String? root,
  Uri? url,
  required List<SiteScreenshotPage> pages,
  required String out,
  List<ScreenshotView> views = const [screenshotMobile],
  List<String> only = const [],
  bool Function(SiteScreenshotPage page, ScreenshotView view)? where,
  String ready = flutterWebSplashHidden,
  Duration settle = const Duration(seconds: 2),
}) => withScreenshotSite(
  root: root,
  url: url,
  spa: true,
  action: (appUrl) async {
    var chrome = await HeadlessChrome.start(
      arguments: headlessChromeFlutterArguments,
    );
    try {
      var screenshotter = await FlutterWebScreenshotter.open(
        await chrome.openPage(),
      );
      return await captureScreenshotFiles(
        pages: pages,
        out: out,
        views: views,
        only: only,
        where: where,
        capture: (page, view) => screenshotter.capture(
          screenshotPageUrl(appUrl, page.path),
          view,
          lang: page.lang,
          ready: ready,
          settle: settle,
        ),
      );
    } finally {
      await chrome.close();
    }
  },
);
