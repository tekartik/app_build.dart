/// The icons of the host (desktop) project of a flutter app, made from one
/// image of the app (`img/app_icon.webp`, itself made from its drawing
/// `img/app_icon.svg`), so that the platform projects stay git ignored and
/// created when missing.
///
/// io only, the app itself never imports it.
library;

export 'src/app_icon.dart'
    show
        FlutterAppLinuxDesktopEntry,
        findFlutterAppIconPath,
        flutterAppIconFromSvg,
        flutterAppWriteIcons;
