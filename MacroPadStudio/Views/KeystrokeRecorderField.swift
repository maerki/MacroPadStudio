import AppKit
import SwiftUI

struct KeystrokeRecorderField: NSViewRepresentable {
    let keystroke: Keystroke
    let onRecord: (Keystroke) -> Void

    func makeNSView(context: Context) -> KeystrokeRecorderView {
        KeystrokeRecorderView(keystroke: keystroke, onRecord: onRecord)
    }

    func updateNSView(_ view: KeystrokeRecorderView, context: Context) {
        view.keystroke = keystroke
        view.onRecord = onRecord
    }
}

final class KeystrokeRecorderView: NSView {
    var keystroke: Keystroke {
        didSet { updateLabel() }
    }
    var onRecord: (Keystroke) -> Void

    private let label = NSTextField(labelWithString: "")
    private var isRecording = false {
        didSet {
            updateLabel()
            needsDisplay = true
        }
    }

    init(keystroke: Keystroke, onRecord: @escaping (Keystroke) -> Void) {
        self.keystroke = keystroke
        self.onRecord = onRecord
        super.init(frame: .zero)

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        label.lineBreakMode = .byTruncatingTail
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 9),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -9),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        setAccessibilityRole(.textField)
        setAccessibilityLabel("Record keystroke")
        setAccessibilityHelp("Click, then press a key or keyboard shortcut")
        toolTip = "Click, then press a key or keyboard shortcut"
        updateLabel()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        guard super.becomeFirstResponder() else { return false }
        isRecording = true
        return true
    }

    override func resignFirstResponder() -> Bool {
        guard super.resignFirstResponder() else { return false }
        isRecording = false
        return true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard let recorded = HIDKeyboardEventTranslator.keystroke(
            keyCode: event.keyCode,
            modifierFlags: event.modifierFlags
        ) else {
            NSSound.beep()
            return
        }
        onRecord(recorded)
        window?.makeFirstResponder(nil)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording, event.type == .keyDown else {
            return super.performKeyEquivalent(with: event)
        }
        keyDown(with: event)
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let bounds = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        NSColor.textBackgroundColor.setFill()
        path.fill()
        (isRecording ? NSColor.keyboardFocusIndicatorColor : NSColor.separatorColor).setStroke()
        path.lineWidth = isRecording ? 2 : 1
        path.stroke()
    }

    private func updateLabel() {
        label.stringValue = isRecording ? "Press shortcut..." : keystroke.displayName
        label.textColor = isRecording ? .controlAccentColor : .labelColor
        setAccessibilityValue(keystroke.displayName)
    }
}

enum HIDKeyboardEventTranslator {
    static func keystroke(
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags
    ) -> Keystroke? {
        guard let key = keysByMacKeyCode[keyCode] else { return nil }
        var modifiers: HIDModifier = []
        if modifierFlags.contains(.control) { modifiers.insert(.leftControl) }
        if modifierFlags.contains(.shift) { modifiers.insert(.leftShift) }
        if modifierFlags.contains(.option) { modifiers.insert(.leftOption) }
        if modifierFlags.contains(.command) { modifiers.insert(.leftCommand) }
        return Keystroke(key: key, modifiers: modifiers)
    }

    private static let keysByMacKeyCode: [UInt16: HIDKey] = [
        0: .a, 1: .s, 2: .d, 3: .f, 4: .h, 5: .g, 6: .z, 7: .x,
        8: .c, 9: .v, 10: .nonUSBackslash, 11: .b, 12: .q, 13: .w, 14: .e, 15: .r,
        16: .y, 17: .t, 18: .one, 19: .two, 20: .three, 21: .four,
        22: .six, 23: .five, 24: .equal, 25: .nine, 26: .seven,
        27: .minus, 28: .eight, 29: .zero, 30: .rightBracket, 31: .o,
        32: .u, 33: .leftBracket, 34: .i, 35: .p, 36: .returnKey,
        37: .l, 38: .j, 39: .quote, 40: .k, 41: .semicolon,
        42: .backslash, 43: .comma, 44: .slash, 45: .n, 46: .m,
        47: .period, 48: .tab, 49: .space, 50: .grave, 51: .backspace,
        53: .escape, 57: .capsLock, 64: .f17, 65: .keypadPeriod,
        67: .keypadAsterisk, 69: .keypadPlus, 71: .keypadNumLock,
        75: .keypadSlash, 76: .keypadEnter, 78: .keypadMinus,
        79: .f18, 80: .f19, 81: .keypadEqual, 82: .keypadZero,
        83: .keypadOne, 84: .keypadTwo, 85: .keypadThree,
        86: .keypadFour, 87: .keypadFive, 88: .keypadSix,
        89: .keypadSeven, 91: .keypadEight, 92: .keypadNine,
        96: .f5, 97: .f6, 98: .f7,
        99: .f3, 100: .f8, 101: .f9, 103: .f11, 105: .f13,
        106: .f16, 107: .f14, 109: .f10, 111: .f12, 113: .f15,
        114: .insert, 115: .home, 116: .pageUp, 117: .delete,
        118: .f4, 119: .end, 120: .f2, 121: .pageDown, 122: .f1,
        123: .leftArrow, 124: .rightArrow, 125: .downArrow, 126: .upArrow
    ]
}
