# tekartik_jaspr_build

Build, check and deploy [jaspr](https://jaspr.site) static sites (`mode:
static`) to Firebase Hosting, one Hosting target per flavor (dev, prod...).

This is not a build_runner builder (that is jaspr's own `jaspr_builder`):
it runs the site's own `jaspr_cli` through a shell and never imports jaspr,
so it adds no analyzer constraint to the package that uses it.

What a build does, on top of `jaspr build`:

- passes `<PREFIX>_SITE_URL`, `<PREFIX>_SITE_NOINDEX`, `<PREFIX>_APP_VERSION`
  and the flavor's own `--dart-define`s;
- writes `robots.txt` (`Disallow: /` when noindex, the sitemap otherwise)
  and a target marker checked before any deploy;
- moves `/404` to `404.html` (and `/<lang>/404` to `i18n/<lang>/404.html`);
- removes the build_runner leftovers (`packages/`, `.dart_tool/`,
  `.build.manifest`) and adds the trailing slashes to the sitemap urls;
- for a site in several languages, copies each page of the other languages
  to `i18n/<lang>/` at the path of its default language version (found
  through its `hreflang` link), so that Firebase Hosting i18n rewrites serve
  it to the browsers asking for that language, and the default language
  pages to `i18n/<default>/` at their own paths.

Deploy and serve then check the build (internal links, canonicals, noindex,
hreflang pairs, i18n copies, sitemap, robots), write `firebase.json` from
the flavors (the `X-Robots-Tag` header follows the noindex flag) and copy the
build to `deploy/firebase/hosting/public`.

## Setup

In the site package (a standalone package, outside any workspace on
analyzer 13: `jaspr_builder` and `jaspr_cli` 0.23 need analyzer 12) or in a
support package:

```yaml
dev_dependencies:
  tekartik_jaspr_build:
    git:
      url: https://github.com/tekartik/app_build.dart
      path: packages/jaspr_build
```

The `firebase` cli must be installed and logged in, `cwebp` (package webp)
for `webpConvert`.

## Usage

`tool/site_tool.dart`:

```dart
import 'package:tekartik_jaspr_build/jaspr_build.dart';

String _appVersion() => pubspecVersion('../my_app');

const mySite = JasprSite(
  path: '.',
  definePrefix: 'MY',
  appVersion: _appVersion,
  languages: ['en', 'fr'],
  flavors: [
    JasprSiteFlavor(
      target: 'dev',
      projectId: 'my-project-dev',
      hostingId: 'my-site-dev',
      url: 'https://my-site-dev.web.app',
      noIndex: true,
    ),
    JasprSiteFlavor(
      target: 'prod',
      projectId: 'my-project',
      hostingId: 'my-site',
      url: 'https://my.example.com',
      noIndex: false,
    ),
  ],
);
```

`tool/site_menu.dart`:

```dart
import 'package:tekartik_jaspr_build/jaspr_build_menu.dart';

import 'site_tool.dart';

void main(List<String> arguments) => mainJasprSiteMenu(arguments, mySite);
```

or one-liners such as `await mySite.buildAndDeploy(mySite.flavor('dev'));`.

The site reads its flags with `String.fromEnvironment('MY_SITE_URL')` and
`bool.fromEnvironment('MY_SITE_NOINDEX')`, and must write, on every page:
a canonical link on the site url, `<meta name="robots" content="noindex,
nofollow">` when noindex (404 pages may always carry it), and, with several
languages, absolute `hreflang` links both ways.

## Screenshots

`jaspr_screenshot.dart` captures a built site with headless Chrome (driven
through the DevTools protocol, the build served by a local server that
resolves urls as Hosting does):

```dart
import 'package:tekartik_jaspr_build/jaspr_screenshot.dart';

await jasprSiteScreenshots(buildPath: 'build/jaspr', out: '.local/shots');
```

writes every page in each language (paired through their `hreflang` links,
the 404 of each language included) on a desktop and a phone, full page:
`01_home_en_desktop.png`, `01_home_fr_mobile.png`...
`captureSiteScreenshots` takes chosen pages and views, a script to run in
each page first and other folders to serve. Chrome is `CHROME_EXECUTABLE`,
else Chrome or Chromium on the path.

## Notes

- `jaspr build` uses a fixed proxy port (5567): two jaspr builds on the same
  machine at the same time fail with "Address already in use". Run them one
  after the other.
- The `i18n` folder is also reachable at `/i18n/...`: `firebase.json` gets a
  `X-Robots-Tag: noindex` rule on it. The rule follows the request path, so
  the copies served at the default urls do not get it.
- Hosting goes through the browser's languages in order and serves the
  first one with an `i18n/` folder; the content outside `i18n/` comes last.
  Hence the `i18n/<default>/` copies: without them `en-US,en;q=0.9,fr;q=0.8`
  gets French. The Hosting emulator serves English there: check the language
  selection on a real (dev) Hosting site.
- With i18n, the pages are sent with `Cache-Control: public, max-age=0,
  s-maxage=300`: the browser cache ignores the language cookie, so a page
  cached in one language would survive the switch; the CDN does key on it.
- To let a visitor override the browser language, the site's language link
  sets the Hosting cookie `firebase-language-override` (`en`, `fr`...).
