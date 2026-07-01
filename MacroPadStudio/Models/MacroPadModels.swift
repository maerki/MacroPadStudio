import Foundation
import SwiftUI

enum DeviceProtocol: String, Codable, Sendable {
    case legacy
    case extended
}

struct DeviceProfile: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let vendorID: UInt16
    let productID: UInt16
    let interfaceNumber: Int
    let deviceProtocol: DeviceProtocol
    let keyCount: Int
    let knobCount: Int
    let layerCount: Int
    let maxSequenceLength: Int
    let supportsDelay: Bool
    let supportsColor: Bool
    let ledModeCount: Int

    static let miniKeyboardExtended = DeviceProfile(
        id: "1189-8840", name: "MINI_KEYBOARD", vendorID: 0x1189, productID: 0x8840,
        interfaceNumber: 0, deviceProtocol: .extended, keyCount: 3, knobCount: 1,
        layerCount: 3, maxSequenceLength: 18, supportsDelay: true, supportsColor: true,
        ledModeCount: 6
    )

    static let legacyMini = DeviceProfile(
        id: "1189-8890", name: "MINI_KEYBOARD", vendorID: 0x1189, productID: 0x8890,
        interfaceNumber: 1, deviceProtocol: .legacy, keyCount: 3, knobCount: 1,
        layerCount: 1, maxSequenceLength: 5, supportsDelay: false, supportsColor: false,
        ledModeCount: 3
    )

    static let supported: [DeviceProfile] = [
        miniKeyboardExtended,
        legacyMini,
        .init(id: "1189-8830", name: "MacroPad 9+2", vendorID: 0x1189, productID: 0x8830, interfaceNumber: 0, deviceProtocol: .extended, keyCount: 9, knobCount: 2, layerCount: 3, maxSequenceLength: 18, supportsDelay: true, supportsColor: true, ledModeCount: 6),
        .init(id: "1189-8831", name: "MacroPad 6+2", vendorID: 0x1189, productID: 0x8831, interfaceNumber: 0, deviceProtocol: .extended, keyCount: 6, knobCount: 2, layerCount: 3, maxSequenceLength: 18, supportsDelay: true, supportsColor: true, ledModeCount: 6),
        .init(id: "1189-8832", name: "MacroPad 12+3", vendorID: 0x1189, productID: 0x8832, interfaceNumber: 0, deviceProtocol: .extended, keyCount: 12, knobCount: 3, layerCount: 3, maxSequenceLength: 18, supportsDelay: true, supportsColor: true, ledModeCount: 6),
        .init(id: "1189-8833", name: "MacroPad 6+1", vendorID: 0x1189, productID: 0x8833, interfaceNumber: 0, deviceProtocol: .extended, keyCount: 6, knobCount: 1, layerCount: 3, maxSequenceLength: 18, supportsDelay: true, supportsColor: true, ledModeCount: 6),
        .init(id: "1189-8810", name: "MacroPad Compact", vendorID: 0x1189, productID: 0x8810, interfaceNumber: 0, deviceProtocol: .extended, keyCount: 6, knobCount: 1, layerCount: 3, maxSequenceLength: 18, supportsDelay: true, supportsColor: true, ledModeCount: 6)
    ]

    static let demo = miniKeyboardExtended
}

enum PadControlID: Hashable, Codable, Sendable, Identifiable {
    case key(Int)
    case knobLeft(Int)
    case knobPush(Int)
    case knobRight(Int)

    var id: String {
        switch self {
        case .key(let number): "key-\(number)"
        case .knobLeft(let number): "knob-\(number)-left"
        case .knobPush(let number): "knob-\(number)-push"
        case .knobRight(let number): "knob-\(number)-right"
        }
    }

    var title: String {
        switch self {
        case .key(let number): "Key \(number)"
        case .knobLeft(let number): "Knob \(number) Left"
        case .knobPush(let number): "Knob \(number) Press"
        case .knobRight(let number): "Knob \(number) Right"
        }
    }

    var knobNumber: Int? {
        switch self {
        case .key: nil
        case .knobLeft(let number), .knobPush(let number), .knobRight(let number): number
        }
    }

    func protocolAction(for profile: DeviceProfile) -> UInt8 {
        switch self {
        case .key(let number): UInt8(clamping: number)
        case .knobLeft(let number):
            profile.deviceProtocol == .extended
                ? UInt8(18 + (number - 1) * 3)
                : UInt8(13 + (number - 1) * 3)
        case .knobPush(let number):
            profile.deviceProtocol == .extended
                ? UInt8(17 + (number - 1) * 3)
                : UInt8(14 + (number - 1) * 3)
        case .knobRight(let number):
            profile.deviceProtocol == .extended
                ? UInt8(16 + (number - 1) * 3)
                : UInt8(15 + (number - 1) * 3)
        }
    }
}

struct HIDModifier: OptionSet, Codable, Hashable, Sendable {
    let rawValue: UInt8

    static let leftControl = HIDModifier(rawValue: 1 << 0)
    static let leftShift = HIDModifier(rawValue: 1 << 1)
    static let leftOption = HIDModifier(rawValue: 1 << 2)
    static let leftCommand = HIDModifier(rawValue: 1 << 3)
    static let rightControl = HIDModifier(rawValue: 1 << 4)
    static let rightShift = HIDModifier(rawValue: 1 << 5)
    static let rightOption = HIDModifier(rawValue: 1 << 6)
    static let rightCommand = HIDModifier(rawValue: 1 << 7)

    var displayNames: [String] {
        var result: [String] = []
        if contains(.leftControl) { result.append("⌃") }
        if contains(.leftOption) { result.append("⌥") }
        if contains(.leftShift) { result.append("⇧") }
        if contains(.leftCommand) { result.append("⌘") }
        if contains(.rightControl) { result.append("R⌃") }
        if contains(.rightOption) { result.append("R⌥") }
        if contains(.rightShift) { result.append("R⇧") }
        if contains(.rightCommand) { result.append("R⌘") }
        return result
    }
}

enum HIDKey: UInt8, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case none = 0
    case a = 4, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z
    case one = 30, two, three, four, five, six, seven, eight, nine, zero
    case returnKey = 40, escape, backspace, tab, space, minus, equal, leftBracket, rightBracket, backslash
    case semicolon = 51, quote, grave, comma, period, slash, capsLock
    case f1 = 58, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12
    case printScreen = 70, scrollLock, pause, insert, home, pageUp, delete, end, pageDown, rightArrow, leftArrow, downArrow, upArrow
    case keypadNumLock = 83, keypadSlash, keypadAsterisk, keypadMinus, keypadPlus, keypadEnter
    case keypadOne = 89, keypadTwo, keypadThree, keypadFour, keypadFive, keypadSix, keypadSeven, keypadEight, keypadNine, keypadZero, keypadPeriod
    case nonUSBackslash = 100
    case keypadEqual = 103
    case f13 = 104, f14, f15, f16, f17, f18, f19

    var id: UInt8 { rawValue }

    var symbolName: String? {
        switch self {
        case .none: return "nosign"
        case .a: return "a.square"
        case .b: return "b.square"
        case .c: return "c.square"
        case .d: return "d.square"
        case .e: return "e.square"
        case .f: return "f.square"
        case .g: return "g.square"
        case .h: return "h.square"
        case .i: return "i.square"
        case .j: return "j.square"
        case .k: return "k.square"
        case .l: return "l.square"
        case .m: return "m.square"
        case .n: return "n.square"
        case .o: return "o.square"
        case .p: return "p.square"
        case .q: return "q.square"
        case .r: return "r.square"
        case .s: return "s.square"
        case .t: return "t.square"
        case .u: return "u.square"
        case .v: return "v.square"
        case .w: return "w.square"
        case .x: return "x.square"
        case .y: return "y.square"
        case .z: return "z.square"
        case .one, .keypadOne: return "1.square"
        case .two, .keypadTwo: return "2.square"
        case .three, .keypadThree: return "3.square"
        case .four, .keypadFour: return "4.square"
        case .five, .keypadFive: return "5.square"
        case .six, .keypadSix: return "6.square"
        case .seven, .keypadSeven: return "7.square"
        case .eight, .keypadEight: return "8.square"
        case .nine, .keypadNine: return "9.square"
        case .zero, .keypadZero: return "0.square"
        case .returnKey, .keypadEnter: return "return"
        case .escape: return "escape"
        case .backspace: return "delete.left"
        case .tab: return "arrow.right.to.line"
        case .space: return "space"
        case .minus, .keypadMinus: return "minus"
        case .equal, .keypadEqual: return "equal"
        case .backslash: return "character"
        case .quote: return "quote.opening"
        case .capsLock: return "capslock"
        case .printScreen: return "camera.viewfinder"
        case .scrollLock: return "lock"
        case .pause: return "pause"
        case .insert: return "text.insert"
        case .home: return "house"
        case .pageUp: return "arrow.up.doc"
        case .delete: return "delete.right"
        case .end: return "arrow.down.right"
        case .pageDown: return "arrow.down.doc"
        case .rightArrow: return "arrow.right"
        case .leftArrow: return "arrow.left"
        case .downArrow: return "arrow.down"
        case .upArrow: return "arrow.up"
        case .keypadNumLock: return "clear"
        case .keypadSlash: return "divide"
        case .keypadAsterisk: return "asterisk"
        case .keypadPlus: return "plus"
        case .leftBracket, .rightBracket, .semicolon, .grave, .comma, .period, .slash,
             .f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10, .f11, .f12, .f13, .f14,
             .f15, .f16, .f17, .f18, .f19, .keypadPeriod, .nonUSBackslash:
            return nil
        }
    }

    var displayName: String {
        switch self {
        case .none: "None"
        case .returnKey: "Return"
        case .escape: "Escape"
        case .backspace: "Delete"
        case .space: "Space"
        case .leftArrow: "←"
        case .rightArrow: "→"
        case .upArrow: "↑"
        case .downArrow: "↓"
        case .pageUp: "Page Up"
        case .pageDown: "Page Down"
        case .capsLock: "Caps Lock"
        case .printScreen: "Screenshot"
        case .scrollLock: "Scroll Lock"
        case .nonUSBackslash: "§"
        case .keypadNumLock: "Keypad Clear"
        case .keypadSlash: "Keypad /"
        case .keypadAsterisk: "Keypad *"
        case .keypadMinus: "Keypad -"
        case .keypadPlus: "Keypad +"
        case .keypadEnter: "Keypad Enter"
        case .keypadOne: "Keypad 1"
        case .keypadTwo: "Keypad 2"
        case .keypadThree: "Keypad 3"
        case .keypadFour: "Keypad 4"
        case .keypadFive: "Keypad 5"
        case .keypadSix: "Keypad 6"
        case .keypadSeven: "Keypad 7"
        case .keypadEight: "Keypad 8"
        case .keypadNine: "Keypad 9"
        case .keypadZero: "Keypad 0"
        case .keypadPeriod: "Keypad ."
        case .keypadEqual: "Keypad ="
        default: String(describing: self).replacingOccurrences(of: "Key", with: "").uppercased()
        }
    }
}

struct Keystroke: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var key: HIDKey
    var modifiers: HIDModifier

    var displayName: String {
        (modifiers.displayNames + [key.displayName]).joined(separator: " ")
    }
}

enum MediaAction: String, CaseIterable, Codable, Sendable, Identifiable {
    case playPause = "Play / Pause"
    case nextTrack = "Next Track"
    case previousTrack = "Previous Track"
    case mute = "Mute"
    case volumeUp = "Volume Up"
    case volumeDown = "Volume Down"

    var id: String { rawValue }
}

enum MouseAction: String, CaseIterable, Codable, Sendable, Identifiable {
    case leftClick = "Left Click"
    case rightClick = "Right Click"
    case middleClick = "Middle Click"
    case scrollUp = "Scroll Up"
    case scrollDown = "Scroll Down"

    var id: String { rawValue }
}

enum ActionKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case macro = "Macro"
    case media = "Media"
    case mouse = "Mouse"
    case disabled = "Disabled"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .macro: "command"
        case .media: "play.fill"
        case .mouse: "computermouse"
        case .disabled: "nosign"
        }
    }
}

enum LEDColor: UInt8, CaseIterable, Codable, Sendable, Identifiable {
    case random = 0x00
    case red = 0x10
    case orange = 0x20
    case yellow = 0x30
    case green = 0x40
    case cyan = 0x50
    case blue = 0x60
    case purple = 0x70

    var id: UInt8 { rawValue }
    var name: String { String(describing: self).capitalized }
    var color: Color {
        switch self {
        case .random: .gray
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .cyan: .cyan
        case .blue: .blue
        case .purple: .purple
        }
    }
}

struct ControlBinding: Codable, Hashable, Sendable {
    var kind: ActionKind = .macro
    var sequence: [Keystroke] = []
    var interKeyDelayMilliseconds: UInt16 = 0
    var mediaAction: MediaAction = .playPause
    var mouseAction: MouseAction = .leftClick

    static let defaultShortcut = ControlBinding(
        sequence: [Keystroke(key: .f5, modifiers: [.leftCommand, .leftShift])]
    )
}

struct LayerLighting: Codable, Hashable, Sendable {
    var enabled = true
    var color: LEDColor = .blue
    var mode: UInt8 = 0
    var brightness = 0.7
}

struct LayerConfiguration: Identifiable, Codable, Hashable, Sendable {
    let id: Int
    var name: String
    var bindings: [PadControlID: ControlBinding]
    var lighting = LayerLighting()
}

struct PadConfiguration: Codable, Hashable, Sendable {
    var profileID: String
    var layers: [LayerConfiguration]

    static func starter(for profile: DeviceProfile) -> PadConfiguration {
        var layers: [LayerConfiguration] = []
        for layerIndex in 0..<profile.layerCount {
            var bindings: [PadControlID: ControlBinding] = [:]
            for key in 1...profile.keyCount {
                var binding = ControlBinding.defaultShortcut
                binding.interKeyDelayMilliseconds = profile.supportsDelay ? 100 : 0
                binding.sequence = [Keystroke(key: HIDKey(rawValue: UInt8(3 + min(key, 26))) ?? .a, modifiers: key == 2 ? [.leftCommand, .leftShift] : [])]
                bindings[.key(key)] = binding
            }
            for knob in 1...profile.knobCount {
                var left = ControlBinding()
                left.kind = .media
                left.mediaAction = .volumeDown
                bindings[.knobLeft(knob)] = left
                var push = ControlBinding()
                push.kind = .media
                push.mediaAction = .mute
                bindings[.knobPush(knob)] = push
                var right = ControlBinding()
                right.kind = .media
                right.mediaAction = .volumeUp
                bindings[.knobRight(knob)] = right
            }
            var lighting = LayerLighting()
            lighting.color = LEDColor.allCases[(layerIndex + 6) % LEDColor.allCases.count]
            layers.append(LayerConfiguration(id: layerIndex, name: layerIndex == 0 ? "Base" : "Layer \(layerIndex + 1)", bindings: bindings, lighting: lighting))
        }
        return PadConfiguration(profileID: profile.id, layers: layers)
    }
}
