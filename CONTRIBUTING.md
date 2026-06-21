# Contributing

Thank you for helping improve MacroPad Studio. Contributions are welcome when
they preserve the project's hardware safety boundaries and focused native UI.

## Before opening a pull request

1. Open an issue for substantial features or a new device profile.
2. Keep one concern per branch and pull request.
3. Generate the project with `xcodegen generate`.
4. Run `./Scripts/test.sh`.
5. Update tests and documentation with the implementation.

## Development setup

Requirements are listed in the [README](README.md#requirements).

```sh
cd MacroPadStudio
brew install xcodegen
./Scripts/test.sh
open MacroPadStudio.xcodeproj
```

The generated `.xcodeproj` is committed for convenient browsing, but
`project.yml` remains authoritative.

## Code expectations

- Follow existing Swift naming and state-management patterns.
- Prefer small, testable types over broad abstractions.
- Keep protocol encoding independent from IOKit and UI state.
- Add concise comments only where protocol behavior is not self-explanatory.
- Do not add telemetry, network access, or an update mechanism without prior
  project discussion.

## Adding hardware support

A product name is not sufficient evidence that two devices share a protocol.
Include all of the following in the device-support issue:

- USB vendor ID, product ID, interface number, usage page, and report sizes.
- Clear photographs or a diagram of the keys and knobs.
- Operating system and connection transport.
- Read-only observations and sanitized report captures.
- Provenance for every report format used.

Investigation must begin read-only. A write path is considered only after its
reports are documented, byte-tested, reviewed, and scoped to an exact device
profile. Follow [docs/HARDWARE_TESTING.md](docs/HARDWARE_TESTING.md).

## Pull request checklist

- The change has focused tests.
- The full test suite passes.
- Hardware writes remain behind the review step.
- No generated build output, device configuration, or personal data is added.
- User-facing behavior and supported hardware documentation are current.
- `CHANGELOG.md` includes a concise entry when appropriate.

By contributing, you agree that your contribution is licensed under the
project's MIT License.
