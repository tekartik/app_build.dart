/// Google cloud region
var gcrRegionBelgium = 'europe-west1';

/// Google cloud project id
class GcrProjectOptions {
  /// Google cloud project id
  final String projectId;

  /// Region
  final String region;

  /// Artifact (repo) name, unique per project
  /// Names may only contain lowercase letters, numbers, and hyphens, and must begin with a letter and end with a letter
  final String name;

  /// Image name, unique per artifact
  /// Must match the image name in the docker-compose file
  final String image;

  /// Deployed service name (exported by the project as part of the url of the service)
  /// The name must use only lowercase alphanumeric characters and dashes, cannot begin or end with a dash, and cannot be longer than 63 characters.
  final String serviceName;

  /// Description
  final String? description;

  /// Memory 1G, 2G, 4G, 8G, 16G, 512MB (default)
  final String? memory;

  /// Constructor
  GcrProjectOptions({
    required this.projectId,
    required this.region,
    required this.name,
    required this.image,
    this.description,
    required this.serviceName,
    this.memory,
  });
}
