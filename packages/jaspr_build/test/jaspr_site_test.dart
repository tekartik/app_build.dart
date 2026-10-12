import 'package:path/path.dart';
import 'package:tekartik_jaspr_build/jaspr_build.dart';
import 'package:test/test.dart';

const _dev = JasprSiteFlavor(
  target: 'dev',
  projectId: 'my-project-dev',
  hostingId: 'my-site-dev',
  url: 'https://my-site-dev.web.app',
  noIndex: true,
  defines: {'MY_WEB_APP_URL': 'https://my-dev.web.app'},
);
const _prod = JasprSiteFlavor(
  target: 'prod',
  projectId: 'my-project',
  hostingId: 'my-site',
  url: 'https://my.youpi.app',
  noIndex: false,
);

String _appVersion() => '1.2.3';

void main() {
  group('JasprSite', () {
    const site = JasprSite(
      path: 'my_site',
      definePrefix: 'MY',
      flavors: [_dev, _prod],
      appVersion: _appVersion,
      sitemapExclude: ['^/og'],
    );

    test('paths', () {
      expect(isAbsolute(site.sitePath), isTrue);
      expect(site.buildPath, join(site.sitePath, 'build', 'jaspr'));
      expect(
        site.hostingPath,
        join(site.sitePath, 'deploy', 'firebase', 'hosting'),
      );
    });

    test('flavors', () {
      expect(site.flavor('prod'), same(_prod));
      expect(() => site.flavor('staging'), throwsArgumentError);
      expect(_prod.deployOptions.hostingId, 'my-site');
      expect(_prod.deployOptions.projectId, 'my-project');
      expect(_prod.deployOptions.target, 'prod');
    });

    test('defines', () {
      expect(site.definesFor(_dev), {
        'MY_SITE_URL': 'https://my-site-dev.web.app',
        'MY_SITE_NOINDEX': 'true',
        'MY_APP_VERSION': '1.2.3',
        'MY_WEB_APP_URL': 'https://my-dev.web.app',
      });
      expect(site.definesFor(_prod).keys, [
        'MY_SITE_URL',
        'MY_SITE_NOINDEX',
        'MY_APP_VERSION',
      ]);
    });

    test('jaspr build arguments', () {
      expect(site.sitemapExcludePattern, '^/404|^/fr/404|^/og');
      expect(site.buildArguments(_prod), [
        '--sitemap-domain',
        'https://my.youpi.app',
        '--sitemap-exclude',
        '^/404|^/fr/404|^/og',
        '--dart-define=MY_SITE_URL=https://my.youpi.app',
        '--dart-define=MY_SITE_NOINDEX=false',
        '--dart-define=MY_APP_VERSION=1.2.3',
      ]);
    });

    test('one language: the first sites', () {
      const site = JasprSite(
        path: 'my_site',
        definePrefix: 'MY',
        flavors: [_dev, _prod],
        languages: ['fr'],
      );
      expect(site.otherLanguages, isEmpty);
      expect(site.sitemapExcludePattern, '^/404');
      expect(site.definesFor(_prod).keys, ['MY_SITE_URL', 'MY_SITE_NOINDEX']);
      expect(
        (site.firebaseJson['hosting'] as List).every(
          (target) => !(target as Map).containsKey('i18n'),
        ),
        isTrue,
      );
    });

    test('i18n in firebase.json with other languages', () {
      expect(
        (site.firebaseJson['hosting'] as List).every(
          (target) => (target as Map)['i18n'] != null,
        ),
        isTrue,
      );
    });
  });
}
