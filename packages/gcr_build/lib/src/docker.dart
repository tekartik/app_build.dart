import 'package:dev_build/shell.dart';
import 'package:process_run/stdio.dart';

/// Kills all running Docker containers on the local machine, via
/// `docker kill` on the IDs listed by `docker ps -q`. Does nothing (and
/// logs to stdout) if no containers are running.
Future<void> dockerKillAll() async {
  var processIds = (await run(r'''
     docker ps -q
  ''')).outLines.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (processIds.isEmpty) {
    stdout.writeln('No processIds found');
    return;
  }
  stdout.writeln('processIds: $processIds');
  await run('''
     docker kill ${processIds.join(' ')}
  ''');
}

/// Get any running process ids
Future<List<String>> dockerComposeGetRunningProcessIds() async {
  var processIds = (await run(r'''
     docker compose ps -q
  ''')).outLines.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  return processIds;
}
