# Security Policy

## Supported versions

MacroPad Studio is currently pre-release. Security fixes are made on the
latest revision only.

## Reporting a vulnerability

Use GitHub's private vulnerability reporting feature for the repository. Do
not open a public issue for vulnerabilities involving:

- unintended or unreviewed HID writes;
- malformed reports that can leave hardware unresponsive;
- bypasses of device-profile matching or the write review step;
- exposed credentials, signing material, or private device data;
- arbitrary file access or code execution.

Include affected versions, reproduction steps, expected and observed
behavior, and the exact hardware VID:PID when relevant. Do not attach private
configuration exports without sanitizing them first.

If private vulnerability reporting is unavailable, open a public issue that
only asks maintainers to enable a private reporting channel. Do not disclose
technical details in that issue.

## Hardware safety

Disconnect the keypad if a report causes repeated reconnects, unexpected key
events, or loss of configuration access. Do not attempt firmware, bootloader,
or undocumented recovery commands through MacroPad Studio.
