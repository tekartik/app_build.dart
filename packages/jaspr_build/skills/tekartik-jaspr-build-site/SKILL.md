---
name: tekartik-jaspr-build-site
description: >-
  Use when a Dart tool/ script or dev menu must build, check, deploy or serve
  a jaspr static site (jaspr mode: static) on Firebase Hosting with
  package:tekartik_jaspr_build: JasprSite (build, postBuild, check,
  copyToHosting, deploy, buildAndDeploy, serve, definesFor, buildArguments,
  firebaseJson), JasprSiteFlavor (target, projectId, hostingId, url, noIndex,
  defines), JasprSiteHosting (headers, redirects), jasprSiteCheck,
  jasprSiteFirebaseJson, the jasprBuild* post build steps, i18n copies for
  Firebase Hosting language rewrites (English default, French by browser
  language), pubspecVersion, webpConvert, and jaspr_build_menu.dart
  (mainJasprSiteMenu, jasprSiteMenuContent).
---

# tekartik_jaspr_build site

`JasprSite` describes a jaspr static site package and its Firebase Hosting
targets (`JasprSiteFlavor`). `build` runs the site's own `jaspr build` with
per flavor `--dart-define`s, then fixes the output for Hosting. `deploy` and
`serve` check the build, write `firebase.json` from the flavors and copy the
build to `deploy/firebase/hosting/public`. The package never imports jaspr.

```dart
import 'package:tekartik_jaspr_build/jaspr_build.dart';

const site = JasprSite(
  path: '.',
  definePrefix: 'MY',
  languages: ['en', 'fr'],
  flavors: [
    JasprSiteFlavor(
      target: 'dev',
      projectId: 'my-project',
      hostingId: 'my-site-dev',
      url: 'https://my-site-dev.web.app',
      noIndex: true,
    ),
  ],
);

Future<void> main() async {
  var dev = site.flavor('dev');
  await site.build(dev);
  print(await site.check(dev));
  await site.deploy(dev);
}
```

## Guidelines

### The site package

* Keep the jaspr site a standalone package (not a workspace member) when the
  workspace has analyzer 13 packages (firebase functions): `jaspr_builder`
  and `jaspr_cli` 0.23 need analyzer 12. `tekartik_jaspr_build` itself can be
  a dev dependency of the site or a dependency of a support package.
* The site must read `<definePrefix>_SITE_URL` and `<definePrefix>_SITE_NOINDEX`
  (`String.fromEnvironment`, `bool.fromEnvironment`), and
  `<definePrefix>_APP_VERSION` when `appVersion` is set. Extra values go in
  `JasprSiteFlavor.defines` by full name.
* Every page except the 404 ones needs exactly one canonical link on the
  flavor url, and `<meta name="robots" content="noindex, nofollow">` exactly
  when the flavor is `noIndex`. `check` fails otherwise.
* Write absolute `hreflang` alternates both ways between language versions.
  The French copy served at an English url is found through the English
  page's `hreflang="fr"` link, so localized slugs (`/legal/` and
  `/fr/mentions-legales/`) need nothing more.

### Flavors and targets

* `target` is the hosting target name in `firebase.json`; `deploy` binds it
  to `hostingId` with `firebase target:apply` (a git ignored `.firebaserc`).
* `url` has no trailing slash. It feeds canonical links (the site's code),
  the sitemap domain and robots.txt.
* `noIndex` drives robots.txt, the `X-Robots-Tag` header of the target and
  the site's noindex meta. Flip it in one place (a `siteLaunched` constant).
* Always build before deploying a flavor: the build carries a target marker
  (`.jaspr_site_target`) and `deploy` refuses a build made for another
  target.

### Languages

* `languages` lists the default language first (served at the root); the
  others live under `/<language>/`. The default is `['en', 'fr']`. A single
  language site passes one (`['fr']`) and gets no i18n.
* With several languages, the build copies each French page to
  `i18n/fr/<english path>`, the English pages to `i18n/en/` at their own
  paths, and `firebase.json` gets `"i18n": {"root": "/i18n"}`: a browser
  asking for French gets French at the English url. Render a French 404 at
  `/fr/404`: it becomes `i18n/fr/404.html`.
* Hosting serves the first browser language that has an `i18n/` folder: the
  `i18n/en/` copies are what keeps `en-US,en;q=0.9,fr;q=0.8` in English. The
  Hosting emulator does not show this; check language selection on the dev
  site with `curl -H 'Accept-Language: ...'`.
* With i18n, pages get `Cache-Control: public, max-age=0, s-maxage=300`:
  browsers revalidate (their cache ignores the language cookie), the CDN
  keeps its 5 minutes (it keys on language and cookie).
* The language link sets the cookie `firebase-language-override` (`en`,
  `fr`) so that a visitor's choice wins over the browser.
* Pages of the default language with no translation must be listed in
  `monolingualPaths` (regular expressions on the url path), or `check`
  reports them.

### Hosting rules

* Never edit the generated `firebase.json` by hand: put the site's own rules
  in `JasprSiteHosting(headers: [...], redirects: [...])`, written as in
  `firebase.json`. They are added to every target.
* Common rules: 5 minutes cache on pages and scripts, a year (immutable) on
  `/fonts/`, a day on images.

## Examples

### A one-liner tool per action

```dart
import 'package:tekartik_jaspr_build/jaspr_build.dart';

String _appVersion() => pubspecVersion('../my_app');

const mySite = JasprSite(
  path: '../my_site',
  definePrefix: 'MY',
  appVersion: _appVersion,
  sitemapExclude: ['^/og'],
  monolingualPaths: ['^/changelog/'],
  hosting: JasprSiteHosting(
    redirects: [
      {'source': '/help', 'destination': '/faq/', 'type': 301},
    ],
  ),
  flavors: [
    JasprSiteFlavor(
      target: 'prod',
      projectId: 'my-project',
      hostingId: 'my-site',
      url: 'https://my.example.com',
      noIndex: false,
    ),
  ],
);

Future<void> main() async {
  await mySite.buildAndDeploy(mySite.flavor('prod'));
}
```

### A menu with the site's own entries

```dart
import 'package:tekartik_jaspr_build/jaspr_build.dart';
import 'package:tekartik_jaspr_build/jaspr_build_menu.dart';

const mySite = JasprSite(
  path: '.',
  definePrefix: 'MY',
  flavors: [
    JasprSiteFlavor(
      target: 'dev',
      projectId: 'my-project',
      hostingId: 'my-site-dev',
      url: 'https://my-site-dev.web.app',
      noIndex: true,
    ),
  ],
);

void main(List<String> arguments) {
  mainJasprSiteMenu(
    arguments,
    mySite,
    extra: () {
      menu('images', () {
        item('convert the logo', () async {
          await webpConvert('img/logo.png', 'web/logo.webp', width: 192);
        });
      });
    },
  );
}
```

### Checking a build, external links included

```dart
import 'package:tekartik_jaspr_build/jaspr_build.dart';

Future<void> main() async {
  var result = await jasprSiteCheck(
    'build/jaspr',
    url: 'https://my.example.com',
    noIndex: false,
    languages: ['en', 'fr'],
    external: true,
  );
  print(result);
}
```

## Common mistakes

* `Address already in use ... port = 5567` during `jaspr build`: another
  jaspr build is running on the machine (fixed proxy port). Run them one
  after the other.
* Every subpage reported with a broken relative script: the page lost its
  `<base href="/">` (jaspr writes it); relative links resolve against it.
* `deploy` throws "The last site build is for prod, not dev": build the
  flavor being deployed first.
* A page served in English to French browsers: it has no `hreflang="fr"`
  alternate, so no i18n copy was made.

## More

* Package README and CHANGELOG.
