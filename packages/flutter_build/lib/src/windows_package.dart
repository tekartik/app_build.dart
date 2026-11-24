import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart';
import 'package:process_run/shell.dart';

/// What a Windows release of a Flutter desktop app is: the names of its
/// package ([flutterWindowsPackage]).
class FlutterWindowsPackageInfo {
  /// The package name (lowercase, `a-z0-9-`): the folder and the `.zip`.
  final String name;

  /// The version (`1.2.3`, `1.2.3+4`).
  final String version;

  /// The executable of the Flutter bundle, without `.exe` (the
  /// `BINARY_NAME` of `windows/CMakeLists.txt`, usually the dart package
  /// name).
  final String executable;

  /// A release of [name] [version].
  const FlutterWindowsPackageInfo({
    required this.name,
    required this.version,
    required this.executable,
  });
}

/// A file made by [flutterWindowsPackage].
class FlutterWindowsPackageFile {
  /// Its path.
  final String path;

  /// Its size (bytes).
  final int size;

  /// Its SHA-256 (hex).
  final String sha256;

  /// A file of [path].
  const FlutterWindowsPackageFile({
    required this.path,
    required this.size,
    required this.sha256,
  });

  /// The file at [path] as it is now: its size and SHA-256 read (an
  /// installer made from [FlutterWindowsPackage.folder], for instance).
  static Future<FlutterWindowsPackageFile> of(String path) async {
    var bytes = await File(path).readAsBytes();
    return FlutterWindowsPackageFile(
      path: path,
      size: bytes.length,
      sha256: crypto.sha256.convert(bytes).toString(),
    );
  }

  /// Its name.
  String get name => basename(path);

  @override
  String toString() => '$name ($size bytes, sha256 $sha256)';
}

/// What [flutterWindowsPackage] made.
class FlutterWindowsPackage {
  /// The folder holding the app, ready to run on another machine (the
  /// bundle and the Visual C++ runtime): what an installer packs.
  final String folder;

  /// The files to download made from it (the `.zip`).
  final List<FlutterWindowsPackageFile> files;

  /// The package in [folder] and its [files].
  const FlutterWindowsPackage({required this.folder, required this.files});
}

/// The architecture of this machine in Flutter's names (`x64`, `arm64`):
/// the `build/windows/<arch>/runner/Release` folder.
String flutterWindowsArch() =>
    Abi.current() == Abi.windowsArm64 ? 'arm64' : 'x64';

/// The release bundle of the Flutter app in [projectDir] (after `flutter
/// build windows --release`).
String flutterWindowsReleaseBundleDir(String projectDir, {String? arch}) =>
    join(
      projectDir,
      'build',
      'windows',
      arch ?? flutterWindowsArch(),
      'runner',
      'Release',
    );

/// [version] as the four numbers of a Windows file version: `1.2.3+4` is
/// `1.2.3.4`, `1.2.3` is `1.2.3.0`; a pre-release suffix is left out
/// (`1.2.3-beta+4` is `1.2.3.4`).
String flutterWindowsFileVersion(String version) {
  var parts = version.split('+');
  var numbers = parts.first.split('-').first.split('.');
  int number(int index) =>
      index < numbers.length ? int.tryParse(numbers[index]) ?? 0 : 0;
  var build = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return '${number(0)}.${number(1)}.${number(2)}.$build';
}

/// The Visual C++ runtime libraries a Flutter Windows app needs next to its
/// executable on a machine where the Visual C++ redistributable is not
/// installed.
const flutterWindowsRuntimeDllNames = [
  'msvcp140.dll',
  'vcruntime140.dll',
  'vcruntime140_1.dll',
];

bool _hasRuntime(String dir) => flutterWindowsRuntimeDllNames.every(
  (name) => File(join(dir, name)).existsSync(),
);

/// The folder of this machine holding [flutterWindowsRuntimeDllNames] for
/// [arch]: the redistributable folder of Visual Studio
/// (`VC\Redist\MSVC\<version>\<arch>\Microsoft.VC*.CRT`, the newest), else
/// the system folder (the libraries installed, of this machine's
/// architecture). Throws a [StateError] when there is none.
Future<String> flutterWindowsRuntimeDir({String? arch}) async {
  arch ??= flutterWindowsArch();
  var environment = Platform.environment;
  var vswhere = join(
    environment['ProgramFiles(x86)'] ?? r'C:\Program Files (x86)',
    'Microsoft Visual Studio',
    'Installer',
    'vswhere.exe',
  );
  if (File(vswhere).existsSync()) {
    var result = await Shell(verbose: false, throwOnError: false)
        .runExecutableArguments(vswhere, [
          '-products',
          '*',
          '-prerelease',
          '-property',
          'installationPath',
        ]);
    var found = <String>[];
    for (var install in result.outLines) {
      var redist = Directory(join(install.trim(), 'VC', 'Redist', 'MSVC'));
      if (!redist.existsSync()) {
        continue;
      }
      for (var version in redist.listSync().whereType<Directory>()) {
        var archDir = Directory(join(version.path, arch));
        if (!archDir.existsSync()) {
          continue;
        }
        for (var crt in archDir.listSync().whereType<Directory>()) {
          var name = basename(crt.path);
          if (name.startsWith('Microsoft.VC') &&
              name.endsWith('.CRT') &&
              _hasRuntime(crt.path)) {
            found.add(crt.path);
          }
        }
      }
    }
    if (found.isNotEmpty) {
      // The newest: `14.44.35112` after `14.9.1`.
      List<int> versionOf(String path) => basename(
        dirname(dirname(path)),
      ).split('.').map((part) => int.tryParse(part) ?? 0).toList();
      found.sort((a, b) {
        var (one, other) = (versionOf(a), versionOf(b));
        for (var i = 0; i < one.length && i < other.length; i++) {
          if (one[i] != other[i]) {
            return one[i].compareTo(other[i]);
          }
        }
        return one.length.compareTo(other.length);
      });
      return found.last;
    }
  }
  var system = join(environment['SystemRoot'] ?? r'C:\Windows', 'System32');
  if (arch == flutterWindowsArch() && _hasRuntime(system)) {
    return system;
  }
  throw StateError(
    'No Visual C++ runtime for $arch on this machine '
    '(${flutterWindowsRuntimeDllNames.join(', ')}): install the C++ '
    'workload of Visual Studio',
  );
}

/// What a release does not need at run time: what the linker and the
/// debugger leave next to the libraries.
const _buildOnlyExtensions = ['.pdb', '.lib', '.exp', '.ilk'];

Future<void> _copyBundle(String from, String to) async {
  await for (var entity in Directory(from).list(recursive: true)) {
    if (entity is! File ||
        _buildOnlyExtensions.contains(extension(entity.path).toLowerCase())) {
      continue;
    }
    var target = File(join(to, relative(entity.path, from: from)));
    await target.parent.create(recursive: true);
    await entity.copy(target.path);
  }
}

/// Packages the Flutter Windows release bundle [bundleDir] (see
/// [flutterWindowsReleaseBundleDir]) of [info] into [outputDir]:
///
/// - the folder `<name>-<version>-windows-<arch>`: the bundle (without what
///   only a build needs: `.pdb`, `.lib`, `.exp`) and, with [runtime], the
///   Visual C++ runtime libraries next to the executable
///   ([flutterWindowsRuntimeDllNames], from [runtimeDir] or
///   [flutterWindowsRuntimeDir]; one the bundle already has is kept), so it
///   runs on a machine without the Visual C++ redistributable. An existing
///   folder is replaced;
/// - with [zip]: `<name>-<version>-windows-<arch>.zip`, that folder (its
///   entries sorted, under its name): unzipped anywhere, the executable
///   runs.
///
/// Pure Dart but for the search of the runtime (Windows; give [runtimeDir]
/// elsewhere, or no [runtime]). Returns the folder (for an installer) and
/// the files made, with their size and SHA-256.
Future<FlutterWindowsPackage> flutterWindowsPackage({
  required String bundleDir,
  required FlutterWindowsPackageInfo info,
  required String outputDir,
  String? arch,
  bool zip = true,
  bool runtime = true,
  String? runtimeDir,
}) async {
  var executable = '${info.executable}.exe';
  if (!File(join(bundleDir, executable)).existsSync()) {
    throw ArgumentError.value(
      bundleDir,
      'bundleDir',
      'no $executable in it (flutter build windows --release first)',
    );
  }
  arch ??= flutterWindowsArch();
  var name = '${info.name}-${info.version}-windows-$arch';
  var folder = Directory(join(outputDir, name));
  if (folder.existsSync()) {
    await folder.delete(recursive: true);
  }
  await folder.create(recursive: true);
  await _copyBundle(bundleDir, folder.path);
  if (runtime) {
    runtimeDir ??= await flutterWindowsRuntimeDir(arch: arch);
    for (var dll in flutterWindowsRuntimeDllNames) {
      var target = File(join(folder.path, dll));
      if (!target.existsSync()) {
        await File(join(runtimeDir, dll)).copy(target.path);
      }
    }
  }
  var files = <FlutterWindowsPackageFile>[];
  if (zip) {
    var paths = [
      await for (var entity in folder.list(recursive: true))
        if (entity is File) entity.path,
    ]..sort();
    var archive = Archive();
    for (var path in paths) {
      var entry = posix.joinAll([
        name,
        ...split(relative(path, from: folder.path)),
      ]);
      archive.add(ArchiveFile.bytes(entry, await File(path).readAsBytes()));
    }
    var file = File(join(outputDir, '$name.zip'));
    await file.writeAsBytes(
      ZipEncoder().encodeBytes(archive, level: DeflateLevel.bestCompression),
    );
    files.add(await FlutterWindowsPackageFile.of(file.path));
  }
  return FlutterWindowsPackage(folder: folder.path, files: files);
}
