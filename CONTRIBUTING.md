# Contributing

Thanks for helping improve Autoclick.

## Pull Requests

Use the repository pull request template and keep descriptions structured as:

- `WHAT`: what changed
- `WHY`: why the change is needed
- `HOW`: implementation and validation notes

## Local Validation

Resolve dependencies:

```sh
xcodebuild -resolvePackageDependencies \
  -project Autoclick.xcodeproj \
  -scheme Autoclick
```

Build Debug:

```sh
xcodebuild build \
  -project Autoclick.xcodeproj \
  -scheme Autoclick \
  -configuration Debug \
  -destination "platform=macOS" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

Build universal Release:

```sh
xcodebuild build \
  -project Autoclick.xcodeproj \
  -scheme Autoclick \
  -configuration Release \
  -destination "generic/platform=macOS" \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```
