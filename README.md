# MacroPad Studio

MacroPad Studio is a native SwiftUI macOS configuration app for inexpensive
USB mini macro keypads sold as `MINI_KEYBOARD`, including the verified
3-key, 1-knob Fydun USB Mini Keypad listing below. It is intended for people
who bought a small programmable macro keyboard, macro pad, shortcut keypad, or
OSU-style volume-control keyboard and need a macOS editor instead of the
vendor Windows tool.

The app provides a focused editor, device configuration reading, automatic USB
sync, and an explicit review step before every hardware write.

![MacroPad Studio editor showing a three-key, one-knob MINI_KEYBOARD configuration](docs/images/macropad-studio-editor.png)

> [!WARNING]
> MacroPad Studio writes configuration reports to USB HID hardware. Device
> variants can share a product name while using different protocols. Only use
> write support with an exact, verified device profile.

## Status

MacroPad Studio is pre-release software. The following hardware has been
physically validated:

| USB VID:PID | Layout | Read | Write | Known listing and search terms |
| --- | --- | --- | --- | --- |
| `1189:8840` | 3 keys, 1 knob, 3 layers | Yes | Yes | Fydun `B0D8LCKGFL`, model `Fyduncmo5xut2nb-11`; sold as "Red Switch Macro Keyboard Plug and Play Ergonomic Customized Knobs USB Mini Keypad for Desktop, Professional Accessories (3 Keys 1 Knob)" |

Other profiles in the source describe known device families but remain
experimental until tested on matching physical hardware.

## Supported keyboards

The verified hardware is a generic `MINI_KEYBOARD` USB HID device. The same
physical-looking keyboard is sold under different names, so the product title
alone is not enough to prove support.

Known supported purchase listing:

- [Fydun Red Switch Macro Keyboard / USB Mini Keypad, 3 Keys 1 Knob, ASIN `B0D8LCKGFL`](https://www.amazon.ca/dp/B0D8LCKGFL)

Search phrases that may describe the same kind of device:

- `MINI_KEYBOARD`
- `Fydun 3 Keys 1 Knob`
- `Fyduncmo5xut2nb-11`
- `B0D8LCKGFL`
- `USB Mini Keypad 3 Keys 1 Knob`
- `Red Switch Macro Keyboard`
- `Customized Knobs USB Mini Keypad`
- `programmable mini macro keyboard with knob`
- `OSU volume control custom shortcut key mini keyboard`

Before writing to hardware, confirm that macOS reports USB VID:PID
`1189:8840` and that the physical layout is exactly 3 keys plus 1 knob.

## Features

- Native macOS interface built with SwiftUI and SF Symbols.
- Three-key, one-knob editor with three configuration layers.
- Keyboard sequences, media controls, mouse actions, and layer lighting.
- Full configuration reading for the validated `1189:8840` device.
- Reviewable change list before any hardware write.
- Local JSON drafts stored in Application Support.
- Continues in the menu bar after the editor window closes; this is enabled by default and configurable in Settings.
- Interactive demo mode when no supported USB device is connected.
- No analytics, update checker, or network code.

## Requirements

- macOS 14 or later
- Xcode 26 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.45 or later

Install XcodeGen with Homebrew:

```sh
brew install xcodegen
```

## Build

`project.yml` is the source of truth for the generated Xcode project.

```sh
./Scripts/build.sh
./Scripts/test.sh
```

To open the project in Xcode:

```sh
xcodegen generate
open MacroPadStudio.xcodeproj
```

## Run and connect

1. Connect the keypad directly over USB.
2. Launch MacroPad Studio.
3. Confirm that the detected VID:PID and physical layout match the device.
4. Read the existing configuration or edit a local draft.
5. Review every pending change before applying it to the keypad.

Bluetooth discovery is read-only. Configuration reading and writing require
the validated USB configuration interface. On the observed BLE
`MINI_KEYBOARD`, macOS exposes only the standard keyboard/mouse/consumer HID
endpoint (`1452:022C`, max output report size 2), not the 65-byte vendor
configuration reports used over USB.

## Safety model

- Hardware writes require a user-facing review and confirmation.
- Configuration reading is enabled only for the physically verified
  `1189:8840` profile.
- The read protocol returns control assignments, not verified lighting data;
  local layer names and lighting are preserved.
- Firmware update, bootloader, and undocumented read reports are intentionally
  unsupported.
- HID encoding is kept pure and covered by byte-level tests.
- The verified HID format does not expose repeat or long-press settings;
  actions run once when their physical control is pressed.
- Hardware integration tests are disabled unless a one-use local token is
  created deliberately. See [Hardware testing](docs/HARDWARE_TESTING.md).

## Package a local build

```sh
./Scripts/package.sh
```

This creates an ad-hoc-signed archive at
`outputs/MacroPad-Studio-macOS.zip` plus a SHA-256 checksum.

Public releases are built with a Developer ID signature and Apple
notarization through `./Scripts/package-notarized.sh`; see
[Releasing](docs/RELEASING.md).

## Project structure

| Path | Purpose |
| --- | --- |
| `MacroPadStudio/Models` | Device profiles and editable configuration |
| `MacroPadStudio/Protocol` | Pure HID encoding and configuration decoding |
| `MacroPadStudio/Services` | IOKit device access and local persistence |
| `MacroPadStudio/ViewModels` | Editor state and guarded apply workflow |
| `MacroPadStudio/Views` | Native macOS interface |
| `MacroPadStudioTests` | Protocol, persistence, UI, and gated hardware tests |
| `Design` | Selected visual reference used for UI QA |

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) before proposing a change. Device
support contributions need exact USB identifiers, a physical layout, captured
evidence, and read-only investigation before writes are considered.

Security issues involving unsafe reports or unintended hardware writes should
follow [SECURITY.md](SECURITY.md), not a public issue.

## License and provenance

MacroPad Studio is licensed under the MIT License. See
[LICENSE](LICENSE), [COPYRIGHT.md](COPYRIGHT.md), and
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Protocol behavior was independently reimplemented with reference to the
GPL-3.0 project [rOzzy1987/MacroPad](https://github.com/rOzzy1987/MacroPad)
and observations from the vendor `MINI_KEYBOARD` application. MacroPad Studio
is not affiliated with or endorsed by the keypad manufacturer or seller.
