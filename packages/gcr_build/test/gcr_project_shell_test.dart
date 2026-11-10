// The fakes are sh scripts.
@TestOn('vm && !windows')
library;

import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:tekartik_gcr_build/gcr.dart';
import 'package:test/test.dart';

/// A fake `docker` and `gcloud`: each call is logged as `<cwd>|<args>` in
/// `$FAKE_LOG`, nothing real runs (nothing is built, pushed nor deployed).
///
/// `docker compose ps -q` answers a container id where a compose file is,
/// and fails elsewhere, as docker does.
const _fakeDocker = r'''#!/bin/sh
echo "$(pwd -P)|docker $*" >> "$FAKE_LOG"
if [ "$1" = "compose" ] && [ "$2" = "ps" ]; then
  if [ -f docker-compose.yml ]; then
    echo "c0ffee"
    exit 0
  fi
  echo "no configuration file provided: not found" >&2
  exit 1
fi
exit 0
''';

const _fakeGcloud = r'''#!/bin/sh
echo "$(pwd -P)|gcloud $*" >> "$FAKE_LOG"
if [ "$1" = "artifacts" ] && [ "$2" = "repositories" ] && [ "$3" = "list" ]; then
  echo "[]"
fi
exit 0
''';

void main() {
  late Directory top;
  late String projectPath;

  /// [projectPath] as the fakes print it (macOS temp folders are links).
  late String projectRealPath;
  late File log;
  late ShellEnvironment env;

  setUp(() async {
    top = await Directory.systemTemp.createTemp('gcr_project_shell_');
    var bin = Directory(join(top.path, 'bin'))..createSync();
    for (var entry in {'docker': _fakeDocker, 'gcloud': _fakeGcloud}.entries) {
      var file = File(join(bin.path, entry.key));
      await file.writeAsString(entry.value);
      await runExecutableArguments('chmod', ['+x', file.path]);
    }
    log = File(join(top.path, 'fake.log'));
    env = ShellEnvironment()
      ..paths.prepend(bin.path)
      ..vars['FAKE_LOG'] = log.path;
    // Never the real docker or gcloud.
    expect(await which('docker', environment: env), join(bin.path, 'docker'));
    expect(await which('gcloud', environment: env), join(bin.path, 'gcloud'));
    shellEnvironment = env;

    // The compose project: a dart package with a generated version file of
    // an older version, the current directory being another package.
    projectPath = join(top.path, 'my_gcr');
    await Directory(join(projectPath, 'lib', 'src')).create(recursive: true);
    await File(
      join(projectPath, 'docker-compose.yml'),
    ).writeAsString('services: {}\n');
    await File(
      join(projectPath, 'pubspec.yaml'),
    ).writeAsString('name: my_gcr\nversion: 1.2.3\n');
    await File(join(projectPath, 'lib', 'src', 'version.dart')).writeAsString(
      "/// Generated - do not edit\nlibrary;\nimport 'package:pub_semver/pub_semver.dart';\n"
      "const packageVersionText = '1.0.0';\n"
      'final packageVersion = Version.parse(packageVersionText);\n',
    );
    projectRealPath = Directory(projectPath).resolveSymbolicLinksSync();
  });

  tearDown(() async {
    shellEnvironment = null;
    await top.delete(recursive: true);
  });

  GcrProject newProject() => GcrProject(
    path: projectPath,
    options: GcrProjectOptions(
      projectId: 'demo-gcr-build-test',
      region: gcrRegionBelgium,
      name: 'my-repo',
      image: 'my_image',
      serviceName: 'my-service',
    ),
  );

  List<String> calls() => log.existsSync() ? log.readAsLinesSync() : [];

  test('kill lists and kills the containers of the project path', () async {
    await newProject().kill();
    expect(calls(), [
      '$projectRealPath|docker compose ps -q',
      '$projectRealPath|docker compose kill',
    ]);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('buildAndDeploy generates the version of the project path', () async {
    await newProject().buildAndDeploy();
    expect(
      File(join(projectPath, 'lib', 'src', 'version.dart')).readAsStringSync(),
      contains("const packageVersionText = '1.2.3'"),
    );
    var dockerCalls = calls().where((call) => call.contains('|docker '));
    expect(dockerCalls, contains('$projectRealPath|docker compose build'));
    // gcloud never reaches a real project: the fake answered.
    expect(
      calls().where((call) => call.contains('|gcloud run deploy')),
      hasLength(1),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
