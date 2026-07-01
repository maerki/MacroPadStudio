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

    func testRecordsIsoSectionKey() {
        XCTAssertEqual(recordedKey(10), .nonUSBackslash)
    }

    func testRecordsKeypadKeys() {
        XCTAssertEqual(recordedKey(65), .keypadPeriod)
        XCTAssertEqual(recordedKey(67), .keypadAsterisk)
        XCTAssertEqual(recordedKey(69), .keypadPlus)
        XCTAssertEqual(recordedKey(71), .keypadNumLock)
        XCTAssertEqual(recordedKey(75), .keypadSlash)
        XCTAssertEqual(recordedKey(76), .keypadEnter)
        XCTAssertEqual(recordedKey(78), .keypadMinus)
        XCTAssertEqual(recordedKey(81), .keypadEqual)
        XCTAssertEqual(recordedKey(82), .keypadZero)
        XCTAssertEqual(recordedKey(83), .keypadOne)
        XCTAssertEqual(recordedKey(92), .keypadNine)
    }

    func testRecordsExtendedFunctionKeysAndInsert() {
        XCTAssertEqual(recordedKey(64), .f17)
        XCTAssertEqual(recordedKey(79), .f18)
        XCTAssertEqual(recordedKey(80), .f19)
        XCTAssertEqual(recordedKey(105), .f13)
        XCTAssertEqual(recordedKey(106), .f16)
        XCTAssertEqual(recordedKey(107), .f14)
        XCTAssertEqual(recordedKey(113), .f15)
        XCTAssertEqual(recordedKey(114), .insert)
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
