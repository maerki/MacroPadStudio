# Hardware Testing

Hardware tests can change or erase keypad configuration. They are excluded
from normal test runs unless a specific one-use token exists in `/tmp`.

## Preconditions

- Confirm the device is exactly USB VID:PID `1189:8840`.
- Confirm the physical layout is three keys and one knob.
- Connect by USB and close other keypad configuration tools.
- Read and record the current configuration first if it must be preserved.
- Review the test source and every report it will send.

## Read-only validation

Create `/tmp/macropadstudio-hardware-read-token` containing exactly:

```text
READ-COMPLETE-PROFILE-1189-8840
```

Then run:

```sh
xcodebuild \
  -project MacroPadStudio.xcodeproj \
  -scheme MacroPadStudio \
  -destination 'platform=macOS' \
  test \
  -only-testing:MacroPadStudioTests/HardwareWriteTests/testReadCompleteProfileFromConnectedDevice
```

The token is deleted before the operation begins.

## Write validation

Do not document or provide a general-purpose token that writes an arbitrary
configuration. Each physical write test must describe its exact intended
result in the test name, token, and review output. The test must read the
configuration back and compare every affected binding before reporting
success.

## Adding a device profile

1. Capture device metadata and read-only behavior.
2. Document report provenance and boundaries.
3. Add pure byte-level fixtures and decoder tests.
4. Add discovery without enabling writes.
5. Review exact write reports separately.
6. Validate on physical hardware with read-back.
7. Update the support matrix in `README.md`.

Never experiment with firmware-update, bootloader, reset, or undocumented
reports through this project.
