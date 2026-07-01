# Releasing

## Prepare

1. Move relevant entries from `Unreleased` in `CHANGELOG.md` into a versioned
   section with the release date.
2. Confirm `README.md` accurately lists validated hardware.
3. Run `./Scripts/test.sh`.
4. Run `./Scripts/package.sh` for a local release candidate.
5. Inspect the archive and test it on a separate macOS user account.

## Public binaries

The local package script uses ad-hoc signing. Such an archive may be attached
only to a GitHub pre-release or draft release when the release notes clearly
state that it is not notarized and may be blocked by Gatekeeper.

Before publishing a normal release binary:

1. Archive with a Developer ID Application identity.
2. Enable hardened runtime and verify entitlements.
3. Submit the archive to Apple's notarization service.
4. Staple the notarization ticket to the application.
5. Verify Gatekeeper assessment on the final artifact.
6. Publish checksums alongside the GitHub release.

Signing identities, App Store Connect credentials, notarization profiles, and
API keys must be provided by the release environment and never committed.

## Notarized package

Create a local notarytool keychain profile once per signing machine:

```sh
xcrun notarytool store-credentials "MacroPadStudio Notary" \
  --apple-id "developer@example.com" \
  --team-id "TEAMID1234" \
  --password "app-specific-password"
```

Then build, notarize, staple, verify, and package the app:

```sh
DEVELOPER_ID_APPLICATION="Developer ID Application: Example Name (TEAMID1234)" \
NOTARYTOOL_PROFILE="MacroPadStudio Notary" \
./Scripts/package-notarized.sh
```

The script creates:

- `outputs/MacroPad-Studio-macOS.zip`
- `outputs/MacroPad-Studio-macOS.zip.sha256`

The script fails if the app is not signed with hardened runtime, if Apple
rejects notarization, if stapling fails, or if Gatekeeper assessment fails.

## GitHub release

- Tag the exact reviewed commit using the changelog version.
- Mark non-notarized builds as pre-release and keep the warning prominent.
- Prefer notarized builds for normal public releases.
- Attach the generated SHA-256 checksum with every binary artifact.
- Include the supported-device matrix and known limitations in release notes.
- Keep GitHub's source archives available for every tag.
