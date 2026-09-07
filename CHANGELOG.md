# Changelog

All notable changes to MacroPad Studio will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project intends to use [Semantic Versioning](https://semver.org/) once
the first public version is tagged.

## [Unreleased]

### Added

- Display the standard HID battery percentage when macOS publishes it for a connected macro pad.

## [0.1.0] - 2026-06-21

### Added

- Native SwiftUI editor for three-key, one-knob macro pads.
- Three layers with keyboard, media, mouse, and lighting assignments.
- Guarded configuration review before USB HID writes.
- Configuration reading for the physically validated `1189:8840` device.
- Demo mode, local draft persistence, and gated hardware integration tests.
- Direct keystroke recording and explicit knob-action selection in the editor.
- Layer-wide lighting controls at the bottom of the device pane.
- Layer selection above the physical keyboard representation in the device pane.

### Fixed

- Correct one-based device layer encoding for extended reports.
- Correct 65-byte report-ID framing for `1189:8840` configuration writes.
- Removed repeat and trigger controls that were not represented in the verified HID protocol.
