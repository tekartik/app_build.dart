/// Copy a web build to a deploy folder ([webAppBuildToDeploy], following its
/// `deploy.yaml`) and the [WebAppDeployer] interface. Dart VM only.
library;

export 'src/build_to_deploy.dart' show webAppBuildToDeploy;
export 'src/deploy_common.dart'
    show
        WebAppDeployOptions,
        webAppDeployDirDefault,
        webAppServeWebPortDefault,
        WebAppDeployer;
