/// The `'europe-west1'` (Belgium) Google Cloud region, for use as
/// [GcrProjectOptions.region].
var gcrRegionBelgium = 'europe-west1';

/// Identifies a Google Cloud Run project/service and how to build and
/// deploy it, used by `GcrProject`.
class GcrProjectOptions {
  /// Google Cloud project ID.
  final String projectId;

  /// Google Cloud region to deploy to (e.g. [gcrRegionBelgium]).
  final String region;

  /// Artifact Registry repository name, unique per project. May only
  /// contain lowercase letters, numbers, and hyphens, and must begin and
  /// end with a letter.
  final String name;

  /// Docker image name, unique per artifact repository. Must match the
  /// image name in the project's `docker-compose` file.
  final String image;

  /// Cloud Run service name, exposed as part of the deployed service's
  /// URL. Must use only lowercase alphanumeric characters and dashes,
  /// cannot begin or end with a dash, and cannot exceed 63 characters.
  final String serviceName;

  /// Human-readable description of the artifact repository, or `null` for
  /// none.
  final String? description;

  /// Memory allocated to the Cloud Run service, one of `'1G'`, `'2G'`,
  /// `'4G'`, `'8G'`, `'16G'`, `'512MB'`; defaults to `'512MB'` when `null`.
  final String? memory;

  /// Creates options for deploying [image] as [serviceName] in
  /// [projectId]/[region], under the artifact repository [name].
  /// [description] and [memory] default to `null` (see their field docs).
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
