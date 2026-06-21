# Contributor and Agent Guidance

These rules apply to human contributors and automated coding agents.

## Source of truth

- `project.yml` defines the Xcode project. Run `xcodegen generate` after
  changing it and do not hand-maintain generated project structure.
- Keep changes scoped. Do not combine unrelated refactors, UI work, and device
  protocol additions in one pull request.
- Do not commit `work/`, `outputs/`, Derived Data, local device captures,
  configuration exports, or credentials.

## Hardware safety

- Keep HID encoding pure and covered by byte-level tests.
- Never send undocumented read, firmware-update, or bootloader reports.
- Never remove or bypass the user-facing review step before hardware writes.
- Do not broaden write support from a product name alone. Match exact USB
  identifiers, interface properties, report ID, report size, and layout.
- Treat new device profiles as experimental until read and write behavior has
  been verified on physical hardware.
- Treat lighting as layer-scoped unless a verified profile proves per-key
  support.
- Preserve one-use gates on hardware integration tests. Normal CI must not
  write to connected hardware.

## UI direction

- Keep the primary editor focused: physical control on the left, action
  sequence in the center, and optional settings in the inspector.
- Use native SwiftUI controls and SF Symbols.
- Avoid decorative containers and custom chrome unless they communicate
  hardware state or improve interaction clarity.
- Maintain keyboard navigation, VoiceOver labels, and macOS conventions.

## Verification

- Run `./Scripts/test.sh` for every behavioral change.
- Add byte-level tests for every HID encoding or decoding change.
- Use the gated procedures in `docs/HARDWARE_TESTING.md` only with matching
  physical hardware and an explicit review of the reports being sent.
- Run `./Scripts/package.sh` before a release candidate, then verify the app
  signature and archive contents.

## Pull requests

- Explain user-visible behavior and hardware risk.
- List the exact tests performed, including VID:PID for physical tests.
- Include screenshots for meaningful UI changes.
- Update `CHANGELOG.md`, documentation, and the hardware support table when
  behavior or validated device support changes.
