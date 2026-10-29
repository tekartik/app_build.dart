import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// The packages of a Dart project as pub resolved them: its
/// `.dart_tool/package_config.json` (in a pub workspace, the one of the
/// workspace) and `.dart_tool/package_graph.json` next to it.
class ProjectPackages {
  /// The package config file.
  final File packageConfigFile;

  /// The root folder of each package (ending with `/`).
  final Map<String, Uri> _roots;

  /// The `lib/` folder of each package (ending with `/`).
  final Map<String, Uri> _libs;

  /// The version of each package, from the package graph.
  final Map<String, String> _versions;

  /// The (non dev) dependencies of each package, from the package graph.
  ///
  /// Null when there is no package graph.
  final Map<String, List<String>>? _dependencies;

  /// The pub cache folder (ending with `/`), null when unknown.
  final Uri? pubCache;

  ProjectPackages._(
    this.packageConfigFile,
    this._roots,
    this._libs,
    this._versions,
    this._dependencies,
    this.pubCache,
  );

  /// The packages of the project at [path] (the current directory by
  /// default).
  ///
  /// Throws a [StateError] when `dart pub get` was not run.
  factory ProjectPackages.load({String? path}) {
    var configFile = findPackageConfigFile(path ?? '.');
    var config = jsonDecode(configFile.readAsStringSync()) as Map;
    var roots = <String, Uri>{};
    var libs = <String, Uri>{};
    for (var package in (config['packages'] as List).cast<Map>()) {
      var name = package['name'] as String;
      var root = _folder(configFile.uri.resolve(package['rootUri'] as String));
      roots[name] = root;
      libs[name] = _folder(
        root.resolve((package['packageUri'] as String?) ?? 'lib/'),
      );
    }
    var versions = <String, String>{};
    Map<String, List<String>>? dependencies;
    var graphFile = File(
      p.join(p.dirname(configFile.path), 'package_graph.json'),
    );
    if (graphFile.existsSync()) {
      try {
        var graph = jsonDecode(graphFile.readAsStringSync()) as Map;
        dependencies = {};
        for (var package in (graph['packages'] as List).cast<Map>()) {
          var name = package['name'] as String;
          if (package['version'] case String version) {
            versions[name] = version;
          }
          dependencies[name] = [
            ...?(package['dependencies'] as List?)?.cast<String>(),
          ];
        }
      } catch (_) {
        // An unknown format: every package is a dependency.
        dependencies = null;
      }
    }
    var pubCacheUri = config['pubCache'] as String?;
    var pubCache = pubCacheUri != null
        ? _folder(configFile.uri.resolve(pubCacheUri))
        : _defaultPubCache();
    return ProjectPackages._(
      configFile,
      roots,
      libs,
      versions,
      dependencies,
      pubCache,
    );
  }

  /// The package names.
  Iterable<String> get names => _roots.keys;

  /// True when [name] is a package of the project.
  bool has(String name) => _roots.containsKey(name);

  /// The root folder of [name] (ending with `/`), null when not a package of
  /// the project.
  Uri? root(String name) => _roots[name];

  /// The `lib/` folder of [name] (ending with `/`), null when not a package
  /// of the project.
  Uri? lib(String name) => _libs[name];

  /// The file of a `package:` [uri], null when its package is not a package
  /// of the project.
  File? libraryFile(Uri uri) {
    if (uri.scheme != 'package' || uri.pathSegments.length < 2) {
      throw ArgumentError.value(uri, 'uri', 'not a package: uri');
    }
    var lib = _libs[uri.pathSegments.first];
    if (lib == null) {
      return null;
    }
    return File.fromUri(lib.resolve(uri.pathSegments.skip(1).join('/')));
  }

  /// The version of [name] (from the package graph, else its pubspec), null
  /// when unknown.
  String? version(String name) {
    var version = _versions[name];
    if (version != null) {
      return version;
    }
    var root = _roots[name];
    if (root == null) {
      return null;
    }
    var pubspec = File.fromUri(root.resolve('pubspec.yaml'));
    if (!pubspec.existsSync()) {
      return null;
    }
    return RegExp(
      r'''^version:\s*['"]?([^\s'"]+)''',
      multiLine: true,
    ).firstMatch(pubspec.readAsStringSync())?.group(1);
  }

  /// [names] and the packages they depend on (not their dev dependencies),
  /// sorted. The names that are not packages of the project are left out.
  ///
  /// Every package of the project without a package graph.
  List<String> dependencies(Iterable<String> names) {
    var graph = _dependencies;
    if (graph == null) {
      return names.any(has) ? (this.names.toList()..sort()) : [];
    }
    var found = <String>{};
    void add(String name) {
      if (!has(name) || !found.add(name)) {
        return;
      }
      var dependencies = graph[name];
      if (dependencies == null) {
        // Not in the graph (an older pub): all the packages then.
        found.addAll(this.names);
        return;
      }
      dependencies.forEach(add);
    }

    names.forEach(add);
    return found.toList()..sort();
  }

  /// True when [name] lives in the pub cache: a hosted version or a git
  /// commit, whose sources never change.
  bool isInPubCache(String name) {
    var root = _roots[name];
    var cache = pubCache;
    if (root == null || cache == null) {
      return false;
    }
    return p.isWithin(
          p.join(cache.toFilePath(), 'hosted'),
          root.toFilePath(),
        ) ||
        p.isWithin(p.join(cache.toFilePath(), 'git'), root.toFilePath());
  }

  /// What identifies the sources of [name]: its version and either its
  /// folder in the pub cache (a hosted version, a git commit) or, for a path
  /// package (a workspace member, an override) whose sources change under
  /// the same version, a hash of its `lib/` folder.
  Map<String, Object?> sourceKey(String name) {
    var version = this.version(name);
    if (isInPubCache(name)) {
      return {
        'version': version,
        'pubCache': p.posix.joinAll(
          p.split(
            p.relative(root(name)!.toFilePath(), from: pubCache!.toFilePath()),
          ),
        ),
      };
    }
    var lib = _libs[name];
    return {
      'version': version,
      'hash': lib == null ? null : folderHash(Directory.fromUri(lib)),
    };
  }
}

/// The package config file of the project at [path]: in it, or in a parent
/// folder (the folder of its pub workspace).
///
/// Throws a [StateError] when not found.
File findPackageConfigFile(String path) {
  var directory = Directory(p.normalize(p.absolute(path)));
  while (true) {
    var file = File(
      p.join(directory.path, '.dart_tool', 'package_config.json'),
    );
    if (file.existsSync()) {
      return file;
    }
    var parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError(
        'no .dart_tool/package_config.json in ${p.absolute(path)} or above: '
        'run dart pub get',
      );
    }
    directory = parent;
  }
}

/// A hash (FNV-1a, 64 bits, as 16 hex digits) of the relative paths and
/// bytes of the files in [directory], empty when missing.
String folderHash(Directory directory) {
  // 0xcbf29ce484222325 (the FNV offset basis) as a signed 64-bit int.
  var hash = -0x340d631b7bdddcdb;
  void add(List<int> bytes) {
    for (var byte in bytes) {
      hash = (hash ^ byte) * 0x100000001b3;
    }
  }

  if (directory.existsSync()) {
    var files =
        directory
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .map(
              (file) => (
                file,
                p.posix.joinAll(
                  p.split(p.relative(file.path, from: directory.path)),
                ),
              ),
            )
            .toList()
          ..sort((a, b) => a.$2.compareTo(b.$2));
    for (var (file, path) in files) {
      add(utf8.encode(path));
      add(const [0]);
      add(file.readAsBytesSync());
      add(const [0]);
    }
  }
  // The two unsigned 32-bit halves (a VM int is signed).
  return [
    hash >>> 32,
    hash & 0xffffffff,
  ].map((half) => half.toRadixString(16).padLeft(8, '0')).join();
}

Uri _folder(Uri uri) => uri.path.endsWith('/') ? uri : Uri.parse('$uri/');

Uri? _defaultPubCache() {
  var env = Platform.environment;
  var path = env['PUB_CACHE'];
  if (path == null) {
    if (Platform.isWindows) {
      var localAppData = env['LOCALAPPDATA'];
      if (localAppData != null) {
        path = p.join(localAppData, 'Pub', 'Cache');
      }
    } else {
      var home = env['HOME'];
      if (home != null) {
        path = p.join(home, '.pub-cache');
      }
    }
  }
  return path == null ? null : Directory(path).absolute.uri;
}
