# tekartik_common_build

Common build helpers:
- version

## Setup

```yaml
dependencies:
  tekartik_common_build:
    git:
      url: https://github.com/tekartik/app_build.dart
      path: packages/common_build
```

## Agent skills

The package ships agent skills in `skills/`:

- `tekartik-common-build-version`: generated `lib/src/version.dart`, version
  bump, `CommonAppBuilder` helpers.
- `tekartik-common-build-formatter`: `formatSize`.

In a project that depends on this package, install them with:

```sh
dart run skills@ get
```
