/// A console menu to build, check, deploy and serve a [JasprSite].
library;

import 'package:dev_build/menu/menu_io.dart';

import 'jaspr_build.dart';

export 'package:dev_build/menu/menu_io.dart'
    show mainMenuConsole, menu, item, write;

/// Declares one menu per flavor of [site]: build, deploy, build and deploy,
/// serve, check (with or without the external links).
void jasprSiteMenuContent(JasprSite site) {
  for (var flavor in site.flavors) {
    menu('target $flavor', () {
      item('build', () async {
        await site.build(flavor);
      });
      item('deploy (last build)', () async {
        await site.deploy(flavor);
      });
      item('build and deploy', () async {
        await site.buildAndDeploy(flavor);
      });
      item('serve (last build, Hosting emulator)', () async {
        await site.serve(flavor);
      });
      item('check (last build)', () async {
        write(await site.check(flavor));
      });
      item('check with the external links (last build)', () async {
        write(await site.check(flavor, external: true));
      });
    });
  }
}

/// The `main` of a site menu tool: [jasprSiteMenuContent], then the
/// site's own entries from [extra] (images, data...).
///
/// ```dart
/// Future<void> main(List<String> arguments) async {
///   mainJasprSiteMenu(arguments, mySite);
/// }
/// ```
void mainJasprSiteMenu(
  List<String> arguments,
  JasprSite site, {
  void Function()? extra,
}) {
  mainMenuConsole(arguments, () {
    jasprSiteMenuContent(site);
    extra?.call();
  });
}
