import 'dart:io';

import 'package:path/path.dart' as p;

/// A tag found in a page and its attributes (names lowercased, values with
/// `&amp;` decoded).
class HtmlTag {
  /// The tag name, lowercased.
  final String name;

  /// The attributes, names lowercased.
  final Map<String, String> attributes;

  /// A tag.
  HtmlTag(this.name, this.attributes);

  /// The value of [attribute], null when missing.
  String? operator [](String attribute) => attributes[attribute];

  @override
  String toString() => '<$name $attributes>';
}

final _tagRegExp = RegExp(
  r'<(a|link|img|script|meta|source|iframe|area|base)\b([^>]*)>',
  caseSensitive: false,
);

final _attributeRegExp = RegExp(
  r'''([a-zA-Z_:][-a-zA-Z0-9_:.]*)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?''',
);

/// The `a`, `link`, `img`, `script`, `meta`, `source`, `iframe`, `area` and
/// `base` tags of [html]. Enough for pages a site generator wrote, not a
/// parser.
List<HtmlTag> htmlScanTags(String html) {
  var tags = <HtmlTag>[];
  for (var match in _tagRegExp.allMatches(html)) {
    var attributes = <String, String>{};
    for (var attribute in _attributeRegExp.allMatches(match.group(2)!)) {
      var value =
          attribute.group(2) ?? attribute.group(3) ?? attribute.group(4) ?? '';
      attributes[attribute.group(1)!.toLowerCase()] = value.replaceAll(
        '&amp;',
        '&',
      );
    }
    tags.add(HtmlTag(match.group(1)!.toLowerCase(), attributes));
  }
  return tags;
}

/// The `<link rel="alternate" hreflang="...">` urls of [tags] by language
/// (`x-default` included).
Map<String, String> htmlAlternates(List<HtmlTag> tags) => {
  for (var tag in tags)
    if (tag.name == 'link' &&
        _hasRel(tag, 'alternate') &&
        tag['hreflang'] != null &&
        tag['href'] != null)
      tag['hreflang']!: tag['href']!,
};

/// The `<base href>` of [tags], null when none.
String? htmlBaseHref(List<HtmlTag> tags) {
  for (var tag in tags) {
    if (tag.name == 'base' && tag['href'] != null) {
      return tag['href'];
    }
  }
  return null;
}

/// The `<link rel="canonical">` urls of [tags].
List<String> htmlCanonicals(List<HtmlTag> tags) => [
  for (var tag in tags)
    if (tag.name == 'link' && _hasRel(tag, 'canonical') && tag['href'] != null)
      tag['href']!,
];

/// True when [tags] hold a robots meta with `noindex`.
bool htmlHasNoIndex(List<HtmlTag> tags) => tags.any(
  (tag) =>
      tag.name == 'meta' &&
      tag['name']?.toLowerCase() == 'robots' &&
      (tag['content'] ?? '').toLowerCase().contains('noindex'),
);

bool _hasRel(HtmlTag tag, String rel) =>
    (tag['rel'] ?? '').toLowerCase().split(RegExp(r'\s+')).contains(rel);

/// The url path of a built file relative to the build folder:
/// `faq/index.html` gives `/faq/`, `index.html` gives `/`, `404.html` gives
/// `/404.html`.
String jasprBuildPathOfFile(String relativeFile) {
  var parts = p.posix.split(p.split(relativeFile).join('/'));
  if (parts.last == 'index.html') {
    parts = parts.sublist(0, parts.length - 1);
    return parts.isEmpty ? '/' : '/${parts.join('/')}/';
  }
  return '/${parts.join('/')}';
}

/// The file of the build folder [buildPath] that Hosting serves for the url
/// [path] (`/faq/` or `/faq` give `faq/index.html`), null when there is none.
String? jasprBuildFileOfPath(String buildPath, String path) {
  var segments = [
    for (var segment in path.split('/'))
      if (segment.isNotEmpty) Uri.decodeComponent(segment),
  ];
  if (segments.contains('..')) {
    return null;
  }
  var base = p.joinAll([buildPath, ...segments]);
  if (!path.endsWith('/') && File(base).existsSync()) {
    return base;
  }
  var index = p.join(base, 'index.html');
  if (File(index).existsSync()) {
    return index;
  }
  return null;
}

/// The html files of [buildPath], relative and with `/` separators, sorted.
List<String> jasprBuildHtmlFiles(String buildPath) {
  var dir = Directory(buildPath);
  if (!dir.existsSync()) {
    return [];
  }
  return [
    for (var entity in dir.listSync(recursive: true, followLinks: false))
      if (entity is File && entity.path.endsWith('.html'))
        p.split(p.relative(entity.path, from: buildPath)).join('/'),
  ]..sort();
}
