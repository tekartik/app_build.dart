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
