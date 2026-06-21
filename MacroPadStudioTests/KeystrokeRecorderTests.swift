import AppKit
import XCTest
@testable import MacroPadStudio

final class KeystrokeRecorderTests: XCTestCase {
    func testRecordsPhysicalLetterWithModifiers() throws {
        let stroke = try XCTUnwrap(HIDKeyboardEventTranslator.keystroke(
            keyCode: 13,
            modifierFlags: [.command, .shift]
        ))

        XCTAssertEqual(stroke.key, .w)
        XCTAssertEqual(stroke.modifiers, [.leftCommand, .leftShift])
    }

    func testRecordsSpecialKeys() {
        XCTAssertEqual(recordedKey(36), .returnKey)
        XCTAssertEqual(recordedKey(49), .space)
        XCTAssertEqual(recordedKey(123), .leftArrow)
        XCTAssertEqual(recordedKey(96), .f5)
    }

    func testRejectsUnsupportedMacKeyCode() {
        XCTAssertNil(HIDKeyboardEventTranslator.keystroke(
            keyCode: UInt16.max,
            modifierFlags: []
        ))
    }

    private func recordedKey(_ keyCode: UInt16) -> HIDKey? {
        HIDKeyboardEventTranslator.keystroke(
            keyCode: keyCode,
            modifierFlags: []
        )?.key
    }
}
