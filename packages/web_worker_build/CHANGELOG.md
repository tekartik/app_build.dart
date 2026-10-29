## 0.1.0

- Initial version: `WebWorkerScript` (a Dart program compiled with dart2js
  into the JavaScript file a web app loads besides its page), `setup` (built
  in `.dart_tool/<package>/<name>/`, again only when the Dart SDK, the
  compiler options, the main or a package of the script changed, then
  copied into the web folder of the app when different), `setupMain` (the
  `bin/` command of a package), `ProjectPackages` (the package config and
  package graph of a project, in a pub workspace too).
