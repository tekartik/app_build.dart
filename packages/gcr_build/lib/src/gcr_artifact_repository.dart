// {
//     'cleanupPolicyDryRun': true,
//     'createTime': '2022-11-13T15:57:13.330908Z',
//     'description':
//         'This repository is created and used by Cloud Functions for storing function docker images.',
//     'format': 'DOCKER',
//     'labels': {'goog-managed-by': 'cloudfunctions'},
//     'mode': 'STANDARD_REPOSITORY',
//     'name': 'projects/my_project/locations/my_region/repositories/my_repo',
//     'satisfiesPzi': true,
//     'sizeBytes': '550708161',
//     'updateTime': '2024-10-04T18:24:41.972377Z'
//   };
/// Google cloud artifact repository
class GcrArtifactRepository {
  /// Name
  final String name;

  List<String> get _parts => name.split('/');

  /// String repo
  String get repository => _parts.last;

  /// String region
  String get region => _parts[3];

  /// String project
  String get project => _parts[1];

  /// Constructor
  GcrArtifactRepository.fromJson(Map map) : name = map['name'] as String;

  @override
  String toString() => name;
}
