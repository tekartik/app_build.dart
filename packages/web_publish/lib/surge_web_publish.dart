/// Deploy a folder to [surge.sh](https://surge.sh) with the `surge` command
/// line: [SurgeWebAppDeployer]. Dart VM only.
library;

export 'src/deploy_common.dart'
    show
        SurgeWebAppDeployOptions,
        surgeWebAppDeployDirDefault,
        firebaseWebAppDeployDirDefault;
export 'src/surge_deploy.dart' show SurgeWebAppDeployer;
