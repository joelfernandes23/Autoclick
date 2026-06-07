# Release Pipeline

The repository has three GitHub Actions workflows:

- `CI` builds Debug and Release on every pull request and on pushes to `master` or `main`.
- `Release Please` opens SemVer release pull requests from conventional commits. It does not publish GitHub Releases.
- `Release` builds a universal macOS app, packages it as a zip, uploads artifacts, creates immutable GitHub Releases, and can update a Homebrew tap.

## Required For Releases

Release Please manages release PRs using:

- `release-please-config.json`
- `.release-please-manifest.json`
- `CHANGELOG.md`
- `Autoclick/Version.xcconfig`

Published releases are created by the `Release` workflow so all assets are attached before GitHub release immutability locks the release.

To publish the version recorded in `.release-please-manifest.json`, run the `Release` workflow manually and set `publish_release` to `true`.

You can also create and push a tag such as `v3.0.0-beta.1`:

```sh
git tag v3.0.0-beta.1
git push origin v3.0.0-beta.1
```

The release workflow always creates a zip artifact. Published releases require signing and notarization secrets. Manual artifact-only runs can still build unsigned artifacts.

Published release runs validate all required Apple and Homebrew secrets before the macOS build starts.

## Release Please Token

Set `RELEASE_PLEASE_TOKEN` to a fine-grained token with repository contents and pull request write access if release PRs should trigger normal CI automatically. Without it, the workflow falls back to `GITHUB_TOKEN`.

## Signing Secrets

Published releases require a Developer ID Application certificate from the Apple Developer account. Export that certificate from Keychain Access as a password-protected `.p12`.

The local machine should show a valid identity before export:

```sh
security find-identity -v -p codesigning
```

Set these repository secrets to sign the app:

- `MACOS_CERTIFICATE_P12`: base64-encoded Developer ID Application certificate exported as `.p12`
- `MACOS_CERTIFICATE_PASSWORD`: password for the `.p12`
- `MACOS_KEYCHAIN_PASSWORD`: temporary CI keychain password
- `DEVELOPER_ID_APPLICATION`: signing identity name, for example `Developer ID Application: Example Team (TEAMID)`

## Notarization Secrets

Set these repository secrets to notarize the signed app:

- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_P8`

Create the App Store Connect API key in Apple Developer/App Store Connect, download the `.p8` file once, and keep the key id and issuer id.

## Configure Apple Secrets

Use the helper script to upload signing and notarization secrets:

```sh
scripts/configure-release-secrets.sh \
  --certificate ~/Desktop/DeveloperIDApplication.p12 \
  --developer-id "Developer ID Application: Example Team (TEAMID)" \
  --app-store-key-id ABC123DEFG \
  --app-store-issuer-id 00000000-0000-0000-0000-000000000000 \
  --app-store-key ~/Downloads/AuthKey_ABC123DEFG.p8
```

The script prompts for the `.p12` password and generates a temporary CI keychain password when one is not provided.

Confirm all release secret names are present:

```sh
gh secret list --repo joelfernandes23/Autoclick
```

## Homebrew Publishing

Create a tap repository, for example `owner/homebrew-tap`, then set:

- Repository variable `HOMEBREW_TAP_REPOSITORY`: `owner/homebrew-tap`
- Repository secret `HOMEBREW_TAP_DEPLOY_KEY`: private SSH deploy key with write access to the tap
- Repository variable `HOMEBREW_CASK_TOKEN`: optional cask token, defaults to `autoclick`

The workflow also supports `HOMEBREW_TAP_TOKEN` as an HTTPS token fallback, but a tap-scoped deploy key is preferred.

When a `v*` tag release succeeds, the workflow writes or updates `Casks/autoclick.rb` in the tap.

The cask file is rendered by `scripts/render-homebrew-cask.sh`, and CI validates the rendered template before each build.

## Publish The Beta

After CI is green and Apple secrets are configured, run:

```sh
gh workflow run Release \
  --repo joelfernandes23/Autoclick \
  --ref master \
  -f version=3.0.0-beta.1 \
  -f publish_release=true
```

Watch the run:

```sh
gh run watch --repo joelfernandes23/Autoclick --exit-status
```

This creates the immutable GitHub Release and updates the Homebrew tap.
