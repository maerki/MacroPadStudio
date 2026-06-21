import Foundation

enum ProtocolDecodingError: LocalizedError, Equatable {
    case unsupportedDevice
    case incompleteResponse(expected: Int, actual: Int)
    case malformedReport
    case unexpectedLayer(expected: Int, actual: Int)
    case unsupportedActionKind(UInt8)
    case unsupportedKey(UInt8)
    case unsupportedMediaAction
    case unsupportedMouseAction

    var errorDescription: String? {
        switch self {
        case .unsupportedDevice:
            return "Configuration reading has only been verified for the 3-key, 1-knob MINI_KEYBOARD (1189:8840)."
        case .incompleteResponse(let expected, let actual):
            return "The keypad returned \(actual) of \(expected) configuration records."
        case .malformedReport:
            return "The keypad returned a malformed configuration record."
        case .unexpectedLayer(let expected, let actual):
            return "The keypad returned layer \(actual) while layer \(expected) was being read."
        case .unsupportedActionKind(let kind):
            return "The keypad returned unsupported action type \(kind)."
        case .unsupportedKey(let key):
            return String(format: "The keypad returned unsupported keyboard usage 0x%02X.", key)
        case .unsupportedMediaAction:
            return "The keypad returned an unsupported media action."
        case .unsupportedMouseAction:
            return "The keypad returned an unsupported mouse action."
        }
    }
}

enum MacroPadProtocolDecoder {
    static let recordsPerLayer = 24

    static func configurationReadRequests(
        profile: DeviceProfile,
        reportID: UInt8
    ) throws -> [HIDReport] {
        guard profile == .miniKeyboardExtended, reportID == 3 else {
            throw ProtocolDecodingError.unsupportedDevice
        }
        return (1...profile.layerCount).map { layer in
            HIDReport(reportID: reportID, payload: [0xFA, 0x0F, 0x03, UInt8(layer)])
        }
    }

    static func applying(
        _ reports: [HIDInputReport],
        to base: PadConfiguration,
        profile: DeviceProfile
    ) throws -> PadConfiguration {
        guard profile == .miniKeyboardExtended else {
            throw ProtocolDecodingError.unsupportedDevice
        }
        let expectedCount = profile.layerCount * recordsPerLayer
        guard reports.count == expectedCount else {
            throw ProtocolDecodingError.incompleteResponse(expected: expectedCount, actual: reports.count)
        }

        var result = base
        if result.layers.count != profile.layerCount {
            result = .starter(for: profile)
        }

        for layerIndex in 0..<profile.layerCount {
            let startIndex = layerIndex * recordsPerLayer
            let layerReports = reports[startIndex..<(startIndex + recordsPerLayer)]
            for report in layerReports {
                guard report.reportID == 3, report.payload.count >= 11,
                      report.payload[0] == 0xFA else {
                    throw ProtocolDecodingError.malformedReport
                }
                let returnedLayer = Int(report.payload[2])
                guard returnedLayer == layerIndex + 1 else {
                    throw ProtocolDecodingError.unexpectedLayer(expected: layerIndex + 1, actual: returnedLayer)
                }
            }

            for (control, slot) in controlSlots(for: profile) {
                let payload = reports[startIndex + slot].payload
                result.layers[layerIndex].bindings[control] = try binding(from: payload)
            }
        }
        result.profileID = profile.id
        return result
    }

    private static func controlSlots(for profile: DeviceProfile) -> [(PadControlID, Int)] {
        var controls = (1...profile.keyCount).map { (PadControlID.key($0), $0 - 1) }
        for knob in 1...profile.knobCount {
            let firstSlot = 15 + (knob - 1) * 3
            controls.append(contentsOf: [
                (.knobLeft(knob), firstSlot),
                (.knobPush(knob), firstSlot + 1),
                (.knobRight(knob), firstSlot + 2)
            ])
        }
        return controls
    }

    private static func binding(from payload: [UInt8]) throws -> ControlBinding {
        var binding = ControlBinding()
        binding.interKeyDelayMilliseconds = UInt16(payload[4]) | (UInt16(payload[5]) << 8)

        switch payload[3] {
        case 0:
            binding.kind = .disabled
            binding.sequence = []
        case 1:
            binding.kind = .macro
            let pairCount = Int(payload[9])
            guard pairCount <= 18 else { throw ProtocolDecodingError.malformedReport }
            guard payload.count >= 10 + pairCount * 2 else {
                throw ProtocolDecodingError.malformedReport
            }
            binding.sequence = try (0..<pairCount).map { index in
                let modifier = HIDModifier(rawValue: payload[10 + index * 2])
                let keyByte = payload[11 + index * 2]
                guard let key = HIDKey(rawValue: keyByte) else {
                    throw ProtocolDecodingError.unsupportedKey(keyByte)
                }
                return Keystroke(key: key, modifiers: modifier)
            }
        case 2:
            binding.kind = .media
            binding.mediaAction = try mediaAction(from: payload)
            binding.sequence = []
        case 3:
            binding.kind = .mouse
            binding.mouseAction = try mouseAction(from: payload)
            binding.sequence = []
        default:
            throw ProtocolDecodingError.unsupportedActionKind(payload[3])
        }
        return binding
    }

    private static func mediaAction(from payload: [UInt8]) throws -> MediaAction {
        guard payload.count >= 14 else { throw ProtocolDecodingError.malformedReport }
        switch (payload[11], payload[12]) {
        case (0x40, 0x00): return .playPause
        case (0x00, 0x01): return .nextTrack
        case (0x80, 0x00): return .previousTrack
        case (0x04, 0x00): return .mute
        case (0x02, 0x00): return .volumeUp
        case (0x01, 0x00): return .volumeDown
        default: throw ProtocolDecodingError.unsupportedMediaAction
        }
    }

    private static func mouseAction(from payload: [UInt8]) throws -> MouseAction {
        guard payload.count >= 16 else { throw ProtocolDecodingError.malformedReport }
        switch (payload[10], payload[13]) {
        case (1, 0): return .leftClick
        case (2, 0): return .rightClick
        case (4, 0): return .middleClick
        case (0, 1): return .scrollUp
        case (0, 0xFF): return .scrollDown
        default: throw ProtocolDecodingError.unsupportedMouseAction
        }
    }
}
