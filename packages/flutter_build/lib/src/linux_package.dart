import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:process_run/shell.dart';

/// What a Linux release of a Flutter desktop app is: the names, texts and
/// dependencies of its packages ([flutterLinuxPackage]).
class FlutterLinuxPackageInfo {
  /// The package name (lowercase, `a-z0-9-`): the folder, the command, the
  /// `.desktop` file, the `.deb`.
  final String name;

  /// The name shown in the app menu.
  final String displayName;

  /// The version (`1.2.3`, `1.2.3+4`).
  final String version;

  /// The executable of the Flutter bundle (the `BINARY_NAME` of
  /// `linux/CMakeLists.txt`, usually the dart package name).
  final String executable;

  /// One line saying what it does.
  final String summary;

  /// More lines, for the `.deb` (optional).
  final String? description;

  /// The `.deb` maintainer (`Name <email>`).
  final String maintainer;

  /// The project page, optional.
  final String? homepage;

  /// A PNG icon file (256 px), or null to use [iconName] from the icon
  /// theme.
  final String? iconPath;

  /// The icon theme name used when [iconPath] is null
  /// (`multimedia-volume-control`).
  final String iconName;

  /// The `.desktop` categories (`AudioVideo;Audio;`).
  final String categories;

  /// The window class of the app (its GTK application id, the
  /// `APPLICATION_ID` of `linux/CMakeLists.txt`): the app menu then groups
  /// its window with its entry.
  final String? wmClass;

  /// The `.deb` dependencies (`libgtk-3-0t64`).
  final List<String> debDepends;

  /// The `.deb` recommended packages.
  final List<String> debRecommends;

  /// The `.deb` section.
  final String debSection;

  /// A release of [name] [version].
  const FlutterLinuxPackageInfo({
    required this.name,
    required this.displayName,
    required this.version,
    required this.executable,
    required this.summary,
    required this.maintainer,
    this.description,
    this.homepage,
    this.iconPath,
    this.iconName = 'application-x-executable',
    this.categories = 'Utility;',
    this.wmClass,
    this.debDepends = const ['libgtk-3-0t64'],
    this.debRecommends = const [],
    this.debSection = 'misc',
  });
}

/// A file made by [flutterLinuxPackage].
class FlutterLinuxPackageFile {
  /// Its path.
  final String path;

  /// Its size (bytes).
  final int size;

  /// Its SHA-256 (hex).
  final String sha256;

  /// A file of [path].
  const FlutterLinuxPackageFile({
    required this.path,
    required this.size,
    required this.sha256,
  });

  /// Its name.
  String get name => basename(path);

  @override
  String toString() => '$name ($size bytes, sha256 $sha256)';
}

/// The architecture of this machine in Flutter's names (`x64`, `arm64`):
/// the `build/linux/<arch>/release/bundle` folder.
String flutterLinuxArch() {
  var machine = Process.runSync('uname', ['-m']).stdout.toString().trim();
  return machine == 'aarch64' || machine == 'arm64' ? 'arm64' : 'x64';
}

/// The release bundle of the Flutter app in [projectDir] (after `flutter
/// build linux --release`).
String flutterLinuxReleaseBundleDir(String projectDir, {String? arch}) => join(
  projectDir,
  'build',
  'linux',
  arch ?? flutterLinuxArch(),
  'release',
  'bundle',
);

String _desktopEntry(FlutterLinuxPackageInfo info, {required String exec}) => [
  '[Desktop Entry]',
  'Type=Application',
  'Name=${info.displayName}',
  'Comment=${info.summary}',
  'Exec=$exec',
  'Icon=${info.iconPath == null ? info.iconName : info.name}',
  'Terminal=false',
  'Categories=${info.categories}',
  if (info.wmClass != null) 'StartupWMClass=${info.wmClass}',
  '',
].join('\n');

/// The install script of the archive: the app copied to
/// `~/.local/opt/<name>`, a `~/.local/bin/<name>` link, its menu entry and
/// its icon; run again, it replaces them.
String _installScript(FlutterLinuxPackageInfo info) =>
    '''
#!/bin/sh
# Installs ${info.displayName} ${info.version} for this user: the app in
# ~/.local/opt/${info.name}, the command ~/.local/bin/${info.name}, its menu
# entry. Run again to update; ./uninstall.sh removes it.
set -e
here=\$(cd "\$(dirname "\$0")" && pwd)
data=\${XDG_DATA_HOME:-\$HOME/.local/share}
target=\$HOME/.local/opt/${info.name}
rm -rf "\$target"
mkdir -p "\$target" "\$HOME/.local/bin" "\$data/applications"
cp -r "\$here/app/." "\$target/"
ln -sf "\$target/${info.executable}" "\$HOME/.local/bin/${info.name}"
if [ -f "\$here/${info.name}.png" ]; then
  mkdir -p "\$data/icons/hicolor/256x256/apps"
  cp "\$here/${info.name}.png" "\$data/icons/hicolor/256x256/apps/${info.name}.png"
fi
sed "s|^Exec=.*|Exec=\$target/${info.executable}|" "\$here/${info.name}.desktop" > "\$data/applications/${info.name}.desktop"
update-desktop-database "\$data/applications" 2>/dev/null || true
echo "${info.displayName} ${info.version} installed: ${info.name} (or the app menu)"
''';

String _uninstallScript(FlutterLinuxPackageInfo info) =>
    '''
#!/bin/sh
# Removes ${info.displayName} installed by install.sh (its data is kept).
data=\${XDG_DATA_HOME:-\$HOME/.local/share}
rm -rf "\$HOME/.local/opt/${info.name}"
rm -f "\$HOME/.local/bin/${info.name}" "\$data/applications/${info.name}.desktop" "\$data/icons/hicolor/256x256/apps/${info.name}.png"
update-desktop-database "\$data/applications" 2>/dev/null || true
echo "${info.displayName} removed"
''';

/// The `.deb` version of [version]: a `+` build number kept (`1.2.3+4`),
/// anything Debian refuses replaced by `.`.
String flutterLinuxDebVersion(String version) =>
    version.replaceAll(RegExp(r'[^A-Za-z0-9.+~-]'), '.');

/// Folders 755, files 644, the executable ones 755: whatever the umask
/// of the machine building them (a group-writable file in a package is a
/// fault).
Future<void> _fixModes(String root) async {
  await Shell(
    verbose: false,
  ).runExecutableArguments('chmod', ['-R', 'u=rwX,go=rX', root]);
}

/// [text] in lines of at most [width] characters, for a `.deb`
/// description.
List<String> _wrap(String text, {int width = 72}) {
  var lines = <String>[];
  for (var paragraph in text.split('\n')) {
    var line = '';
    for (var word in paragraph.split(RegExp(r'\s+'))) {
      if (word.isEmpty) {
        continue;
      }
      if (line.isNotEmpty && line.length + 1 + word.length > width) {
        lines.add(line);
        line = word;
      } else {
        line = line.isEmpty ? word : '$line $word';
      }
    }
    if (line.isNotEmpty) {
      lines.add(line);
    }
  }
  return lines;
}

Future<FlutterLinuxPackageFile> _fileOf(String path) async {
  var bytes = await File(path).readAsBytes();
  return FlutterLinuxPackageFile(
    path: path,
    size: bytes.length,
    sha256: sha256.convert(bytes).toString(),
  );
}

Future<void> _copyDirectory(String from, String to) async {
  await Directory(to).create(recursive: true);
  // cp keeps the executable bits of the bundle.
  var result = await Shell(
    verbose: false,
    throwOnError: false,
  ).runExecutableArguments('cp', ['-r', '$from/.', to]);
  if (result.exitCode != 0) {
    throw StateError('cp $from $to failed: ${result.errText}');
  }
}

/// Packages the Flutter Linux release bundle [bundleDir] (see
/// [flutterLinuxReleaseBundleDir]) of [info] into [outputDir]:
///
/// - [tarGz]: `<name>-<version>-linux-<arch>.tar.gz`, a folder of the same
///   name holding the bundle (`app/`), the menu entry, the icon, and an
///   `install.sh` (for the user, no root) and an `uninstall.sh`; any
///   distribution with the libraries the bundle needs;
/// - [deb]: `<name>_<version>_<deb arch>.deb`, the bundle in
///   `/opt/<name>`, the command `/usr/bin/<name>`, the menu entry, the
///   icon, the dependencies of [info] (`apt install ./<file>.deb` installs
///   them).
///
/// Uses `tar` and `dpkg-deb` (Debian, Ubuntu). Returns the files made, with
/// their size and SHA-256.
Future<List<FlutterLinuxPackageFile>> flutterLinuxPackage({
  required String bundleDir,
  required FlutterLinuxPackageInfo info,
  required String outputDir,
  String? arch,
  bool tarGz = true,
  bool deb = true,
}) async {
  if (!File(join(bundleDir, info.executable)).existsSync()) {
    throw ArgumentError.value(
      bundleDir,
      'bundleDir',
      'no ${info.executable} in it (flutter build linux --release first)',
    );
  }
  arch ??= flutterLinuxArch();
  await Directory(outputDir).create(recursive: true);
  var work = await Directory.systemTemp.createTemp('flutter_linux_package');
  var shell = Shell(verbose: false);
  var files = <FlutterLinuxPackageFile>[];
  try {
    if (tarGz) {
      var folder = '${info.name}-${info.version}-linux-$arch';
      var root = join(work.path, folder);
      await _copyDirectory(bundleDir, join(root, 'app'));
      await File(
        join(root, '${info.name}.desktop'),
      ).writeAsString(_desktopEntry(info, exec: info.name));
      if (info.iconPath != null) {
        await File(info.iconPath!).copy(join(root, '${info.name}.png'));
      }
      for (var (script, text) in [
        ('install.sh', _installScript(info)),
        ('uninstall.sh', _uninstallScript(info)),
      ]) {
        var file = File(join(root, script));
        await file.writeAsString(text);
        await shell.runExecutableArguments('chmod', ['755', file.path]);
      }
      await _fixModes(root);
      var archive = join(outputDir, '$folder.tar.gz');
      await shell.runExecutableArguments('tar', [
        '--owner=0',
        '--group=0',
        '--sort=name',
        '-C',
        work.path,
        '-czf',
        absolute(archive),
        folder,
      ]);
      files.add(await _fileOf(archive));
    }
    if (deb) {
      var debArch = arch == 'arm64' ? 'arm64' : 'amd64';
      var version = flutterLinuxDebVersion(info.version);
      var root = join(work.path, 'deb');
      await _copyDirectory(bundleDir, join(root, 'opt', info.name));
      await Directory(join(root, 'usr', 'bin')).create(recursive: true);
      await Link(
        join(root, 'usr', 'bin', info.name),
      ).create('/opt/${info.name}/${info.executable}');
      var applications = join(root, 'usr', 'share', 'applications');
      await Directory(applications).create(recursive: true);
      await File(join(applications, '${info.name}.desktop')).writeAsString(
        _desktopEntry(info, exec: '/opt/${info.name}/${info.executable}'),
      );
      if (info.iconPath != null) {
        var icons = join(
          root,
          'usr',
          'share',
          'icons',
          'hicolor',
          '256x256',
          'apps',
        );
        await Directory(icons).create(recursive: true);
        await File(info.iconPath!).copy(join(icons, '${info.name}.png'));
      }
      var installedSize =
          (await _directorySize(Directory(root)) + 1023) ~/ 1024;
      var control = Directory(join(root, 'DEBIAN'));
      await control.create();
      var description = [
        info.summary,
        for (var line in _wrap(info.description ?? '')) ' $line',
      ].join('\n');
      await File(join(control.path, 'control')).writeAsString(
        [
          'Package: ${info.name}',
          'Version: $version',
          'Section: ${info.debSection}',
          'Priority: optional',
          'Architecture: $debArch',
          'Installed-Size: $installedSize',
          'Maintainer: ${info.maintainer}',
          if (info.debDepends.isNotEmpty)
            'Depends: ${info.debDepends.join(', ')}',
          if (info.debRecommends.isNotEmpty)
            'Recommends: ${info.debRecommends.join(', ')}',
          if (info.homepage != null) 'Homepage: ${info.homepage}',
          'Description: $description',
          '',
        ].join('\n'),
      );
      await _fixModes(root);
      var package = join(outputDir, '${info.name}_${version}_$debArch.deb');

      await shell.runExecutableArguments('dpkg-deb', [
        '--root-owner-group',
        '--build',
        root,
        absolute(package),
      ]);
      files.add(await _fileOf(package));
    }
  } finally {
    await work.delete(recursive: true);
  }
  return files;
}

Future<int> _directorySize(Directory directory) async {
  var size = 0;
  await for (var entity in directory.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is File) {
      size += await entity.length();
    }
  }
  return size;
}
