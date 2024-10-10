// Example showing how to use the JsonCodable macro
import 'package:tekartik_gcr_build/gcr.dart';
import 'package:test/test.dart';

void main() {
  test('GcrArtifactRepository', () {
    var artifactRepositoryMap = {
      'cleanupPolicyDryRun': true,
      'createTime': '2022-11-13T15:57:13.330908Z',
      'description':
          'This repository is created and used by Cloud Functions for storing function docker images.',
      'format': 'DOCKER',
      'labels': {'goog-managed-by': 'cloudfunctions'},
      'mode': 'STANDARD_REPOSITORY',
      'name': 'projects/my_project/locations/my_region/repositories/my_repo',
      'satisfiesPzi': true,
      'sizeBytes': '550708161',
      'updateTime': '2024-10-04T18:24:41.972377Z'
    };
    var repo = GcrArtifactRepository.fromJson(artifactRepositoryMap);
    expect(repo.name,
        'projects/my_project/locations/my_region/repositories/my_repo');
    expect(repo.project, 'my_project');
    expect(repo.region, 'my_region');
    expect(repo.repository, 'my_repo');
  });
}
