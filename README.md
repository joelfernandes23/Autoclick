# Autoclick

[![CI](https://github.com/joelfernandes23/Autoclick/actions/workflows/ci.yml/badge.svg)](https://github.com/joelfernandes23/Autoclick/actions/workflows/ci.yml)

Autoclick is a macOS utility that simulates mouse clicks when needed. It is configurable, lightweight, and designed for common repeated-click workflows.

This repository is a maintained fork of the original archived Autoclick project. The app name remains Autoclick, and the original GPLv2 license and project history are preserved.

<img src="screenshot.png" width="400" alt="Autoclick screenshot" />

## Status

- Maintained fork
- Swift migration in progress
- Apple Silicon and Intel universal builds supported
- CI builds Debug and universal Release configurations
- SemVer release PRs prepared by Release Please
- First maintained release line is planned as `v3.0.0-beta.1`

## Installation

Release builds are published through GitHub Releases.

Homebrew Cask support is available through a tap:

```sh
brew install --cask joelfernandes23/tap/autoclick
```

Current beta builds are unsigned and not notarized. macOS may show a Gatekeeper warning on first launch.

## Build From Source

Requirements:

- macOS
- Xcode 26.5 or newer

Development workflow notes are in [docs/development.md](docs/development.md).

Resolve packages:

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

Build a universal Release app:

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

## Permissions

Autoclick needs macOS Accessibility permission so it can post click events. Recent macOS versions may also require Input Monitoring so global shortcuts and pause controls work reliably.

If clicking or shortcuts do not work:

1. Open System Settings.
2. Go to Privacy & Security.
3. Enable Autoclick under Accessibility.
4. Enable Autoclick under Input Monitoring if prompted.
5. Restart Autoclick.

If macOS keeps asking for the same permission after it is enabled, remove Autoclick from that Privacy & Security list, add `/Applications/Autoclick.app` again, then quit and reopen Autoclick. This can happen with unsigned beta builds after upgrading.

## Release Process

See [docs/release.md](docs/release.md) for SemVer release PRs, unsigned beta releases, immutable GitHub Releases, and Homebrew tap setup. See [CHANGELOG.md](CHANGELOG.md) for release notes.

## License

Autoclick is licensed under GPLv2. See [LICENSE](LICENSE).

## Credits

Autoclick was originally created by Mahdi Bchatnia. This maintained fork preserves the original license and project history while continuing development under joelfernandes23.

## Changelog

### 3.0.0-beta.1

- Planned first maintained fork prerelease.
- Migrates core clicker and number field logic to Swift.
- Adds CI and release automation for universal macOS builds.
- Updates ShortcutRecorder dependency resolution through SwiftPM.

### 2.0.5 (2022/1/28)

- Increase the maximum clicks per second to 900.
- Last release from the original archived project.

### 2.0.4 (2021/9/6)

- Fixed app not remembering your settings between restarts.
- App now checks Input Monitoring permission too, to make sure that you can stop the clicking with keyboard shortcuts/FN key.

### 2.0.3 (2021/2/23)

- Allow hotkeys without modifiers, [#2](https://github.com/inket/Autoclick/issues/2).

### 2.0.2 (2021/2/17)

- Better fix for multi-monitor setups, [#1](https://github.com/inket/Autoclick/issues/1).

### 2.0.1 (2021/2/6)

- Fixed cursor jumping in multi-monitor setups, #1.

### 2.0 (2021)

- Codesigned and notarized so that it is trusted by new versions of macOS.
- Modernized codebase and added Apple Silicon support.
- Displays the Accessibility permission prompt if permission has not been granted yet.

### 1.0 (2011)

- Initial version.
