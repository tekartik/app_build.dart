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
/// A Google Cloud Artifact Registry repository, as returned by the Google
/// Cloud API (see [GcrArtifactRepository.fromJson]).
class GcrArtifactRepository {
  /// Fully-qualified resource name, e.g.
  /// `'projects/my_project/locations/my_region/repositories/my_repo'`.
  final String name;

  List<String> get _parts => name.split('/');

  /// Repository ID, the last segment of [name].
  String get repository => _parts.last;

  /// Region (location) ID, parsed from [name].
  String get region => _parts[3];

  /// Project ID, parsed from [name].
  String get project => _parts[1];

  /// Creates a repository from a decoded JSON [map] (as returned by the
  /// Google Cloud Artifact Registry API), reading its `name` field.
  GcrArtifactRepository.fromJson(Map map) : name = map['name'] as String;

  @override
  String toString() => name;
}
