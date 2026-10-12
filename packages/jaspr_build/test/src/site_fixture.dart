import 'dart:io';

import 'package:path/path.dart';

/// A fake `build/jaspr` folder in the system temp folder.
class SiteFixture {
  /// The folder.
  final String path;

  SiteFixture._(this.path);

  /// A new empty folder.
  static Future<SiteFixture> create() async => SiteFixture._(
    (await Directory.systemTemp.createTemp('jaspr_build_test')).path,
  );

  /// Deletes the folder.
  Future<void> delete() => Directory(path).delete(recursive: true);

  /// Writes [content] to [relative] (`/` separators).
  void file(String relative, String content) {
    File(join(path, relative))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  /// True when [relative] exists.
  bool exists(String relative) =>
      FileSystemEntity.typeSync(join(path, relative)) !=
      FileSystemEntityType.notFound;

  /// Deletes the file [relative].
  void remove(String relative) => File(join(path, relative)).deleteSync();

  /// Reads [relative].
  String read(String relative) => File(join(path, relative)).readAsStringSync();

  /// Writes a page the way jaspr does (`<base href="/">`, attributes in any
  /// order).
  void page(
    String relative, {
    String lang = 'en',
    String? canonical,
    Map<String, String> alternates = const {},
    bool noIndex = false,
    List<String> links = const [],
    String title = 'page',
  }) {
    file(relative, '''<!DOCTYPE html>
<html lang="$lang"><head><base href="/"/>
<meta charset="utf-8"/>
<title>$title</title>
${noIndex ? '<meta name="robots" content="noindex, nofollow"/>' : ''}
${canonical == null ? '' : '<link href="$canonical" rel="canonical"/>'}
${alternates.entries.map((entry) => '<link hreflang="${entry.key}" href="${entry.value}" rel="alternate"/>').join('\n')}
<script src="main.client.dart.js" defer></script>
</head><body>
${links.map((link) => '<a href="$link">link</a>').join('\n')}
</body></html>
''');
  }

  /// Writes `sitemap.xml` listing [locs].
  void sitemap(List<String> locs) {
    file('sitemap.xml', '''<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${locs.map((loc) => '  <url>\n    <loc>$loc</loc>\n  </url>').join('\n')}
</urlset>
''');
  }
}
