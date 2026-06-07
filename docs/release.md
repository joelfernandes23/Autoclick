# Release Pipeline

The repository has two GitHub Actions workflows:

- `CI` builds Debug and Release on every pull request and on pushes to `master` or `main`.
- `Release` builds a universal macOS app, packages it as a zip, uploads artifacts, creates a GitHub Release for `v*` tags, and can update a Homebrew tap.

## Required For Releases

Create a tag such as `v2.1.0` and push it:

```sh
git tag v2.1.0
git push origin v2.1.0
```

The release workflow will always create a zip artifact. Signing, notarization, and Homebrew publishing are enabled only when the matching secrets or variables exist.

## Signing Secrets

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

## Homebrew Publishing

Create a tap repository, for example `owner/homebrew-tap`, then set:

- Repository variable `HOMEBREW_TAP_REPOSITORY`: `owner/homebrew-tap`
- Repository secret `HOMEBREW_TAP_TOKEN`: token with write access to that tap
- Repository variable `HOMEBREW_CASK_TOKEN`: optional cask token, defaults to `autoclick`

When a `v*` tag release succeeds, the workflow writes or updates `Casks/autoclick.rb` in the tap.
