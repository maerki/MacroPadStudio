import Foundation

struct HIDReport: Equatable, Sendable {
    let reportID: UInt8
    let payload: [UInt8]

    init(reportID: UInt8, payload: [UInt8]) {
        self.reportID = reportID
        self.payload = Array(payload.prefix(64)) + Array(repeating: 0, count: max(0, 64 - payload.count))
    }
}

struct HIDInputReport: Equatable, Sendable {
    let reportID: UInt8
    let payload: [UInt8]
}

enum ProtocolEncodingError: LocalizedError, Equatable {
    case sequenceTooLong(maximum: Int)
    case emptySequence
    case unsupportedDelay
    case unsupportedLEDMode(maximum: Int)
    case controlOutOfRange

    var errorDescription: String? {
        switch self {
        case .sequenceTooLong(let maximum): "This device supports at most \(maximum) keystrokes."
        case .emptySequence: "Add at least one keystroke before applying."
        case .unsupportedDelay: "This device does not support an inter-key delay."
        case .unsupportedLEDMode(let maximum): "This device supports LED modes 0 through \(maximum)."
        case .controlOutOfRange: "The selected key or knob is not available on this device."
        }
    }
}

enum MacroPadProtocolEncoder {
    static func reports(
        for control: PadControlID,
        layer: Int,
        binding: ControlBinding,
        profile: DeviceProfile,
        reportID: UInt8
    ) throws -> [HIDReport] {
        guard controlIsValid(control, for: profile) else { throw ProtocolEncodingError.controlOutOfRange }
        if binding.kind == .macro {
            guard !binding.sequence.isEmpty else { throw ProtocolEncodingError.emptySequence }
            guard binding.sequence.count <= profile.maxSequenceLength else {
                throw ProtocolEncodingError.sequenceTooLong(maximum: profile.maxSequenceLength)
            }
            if !profile.supportsDelay && binding.interKeyDelayMilliseconds > 0 {
                throw ProtocolEncodingError.unsupportedDelay
            }
        }

        switch profile.deviceProtocol {
        case .extended:
            return [extendedReport(for: control, layer: layer, binding: binding, profile: profile, reportID: reportID)]
        case .legacy:
            return legacyReports(for: control, layer: layer, binding: binding, profile: profile, reportID: reportID)
        }
    }

    static func lightingReport(
        layer: Int,
        lighting: LayerLighting,
        profile: DeviceProfile,
        reportID: UInt8
    ) throws -> [HIDReport] {
        guard Int(lighting.mode) < profile.ledModeCount else {
            throw ProtocolEncodingError.unsupportedLEDMode(maximum: max(0, profile.ledModeCount - 1))
        }
        let encodedColor = profile.supportsColor ? lighting.color.rawValue : 0
        let encodedMode = lighting.enabled ? lighting.mode : 0
        switch profile.deviceProtocol {
        case .extended:
            var payload = [UInt8](repeating: 0, count: 64)
            payload[0] = 0xFE
            payload[1] = 0xB0
            let deviceLayer = UInt8(clamping: layer + 1)
            payload[2] = deviceLayer
            payload[3] = 0x08
            payload[10] = deviceLayer
            payload[11] = encodedMode | encodedColor
            payload[9] = 1
            return [HIDReport(reportID: reportID, payload: payload)]
        case .legacy:
            var led = [UInt8](repeating: 0, count: 64)
            led[0] = 0xB0
            led[1] = 0x08
            led[2] = encodedMode | encodedColor
            var commit = [UInt8](repeating: 0, count: 64)
            commit[0] = 0xAA
            commit[1] = 0xA1
            return [HIDReport(reportID: reportID, payload: led), HIDReport(reportID: reportID, payload: commit)]
        }
    }

    private static func extendedReport(
        for control: PadControlID,
        layer: Int,
        binding: ControlBinding,
        profile: DeviceProfile,
        reportID: UInt8
    ) -> HIDReport {
        var payload = [UInt8](repeating: 0, count: 64)
        payload[0] = 0xFE
        payload[1] = binding.kind == .disabled ? 0 : control.protocolAction(for: profile)
        payload[2] = UInt8(clamping: layer + 1)
        payload[3] = keyType(for: binding.kind)
        payload[4] = UInt8(truncatingIfNeeded: binding.interKeyDelayMilliseconds)
        payload[5] = UInt8(truncatingIfNeeded: binding.interKeyDelayMilliseconds >> 8)

        let data = actionData(for: binding, reportID: reportID)
        var nonzeroPairCount = 0
        for (index, byte) in data.prefix(54).enumerated() {
            payload[10 + index] = byte
            if byte != 0 { nonzeroPairCount = (index / 2) + 1 }
        }
        payload[9] = UInt8(clamping: nonzeroPairCount)
        return HIDReport(reportID: reportID, payload: payload)
    }

    private static func legacyReports(
        for control: PadControlID,
        layer: Int,
        binding: ControlBinding,
        profile: DeviceProfile,
        reportID: UInt8
    ) -> [HIDReport] {
        var reports: [HIDReport] = []
        if reportID != 0 {
            var selectLayer = [UInt8](repeating: 0, count: 64)
            selectLayer[0] = 0xA1
            selectLayer[1] = UInt8(clamping: layer)
            reports.append(HIDReport(reportID: reportID, payload: selectLayer))
        }

        switch binding.kind {
        case .macro:
            let sequence = binding.sequence.isEmpty ? [Keystroke(key: .none, modifiers: [])] : binding.sequence
            for index in 0...sequence.count {
                var payload = [UInt8](repeating: 0, count: 64)
                payload[0] = control.protocolAction(for: profile)
                payload[1] = 0x01 | (reportID == 0 ? 0 : UInt8(clamping: layer << 4))
                payload[2] = UInt8(clamping: sequence.count)
                payload[3] = UInt8(clamping: index)
                let stroke = index == 0 ? sequence[0] : sequence[index - 1]
                payload[4] = stroke.modifiers.rawValue
                payload[5] = index == 0 ? 0 : stroke.key.rawValue
                reports.append(HIDReport(reportID: reportID, payload: payload))
            }
        case .media, .mouse, .disabled:
            var payload = [UInt8](repeating: 0, count: 64)
            payload[0] = binding.kind == .disabled ? 0 : control.protocolAction(for: profile)
            payload[1] = keyType(for: binding.kind) | (reportID == 0 ? 0 : UInt8(clamping: layer << 4))
            let data = actionData(for: binding, reportID: reportID)
            for (index, byte) in data.prefix(8).enumerated() { payload[2 + index] = byte }
            reports.append(HIDReport(reportID: reportID, payload: payload))
        }

        var commit = [UInt8](repeating: 0, count: 64)
        commit[0] = 0xAA
        commit[1] = 0xAA
        reports.append(HIDReport(reportID: reportID, payload: commit))
        return reports
    }

    private static func keyType(for kind: ActionKind) -> UInt8 {
        switch kind {
        case .macro: 0x01
        case .media: 0x02
        case .mouse: 0x03
        case .disabled: 0x00
        }
    }

    private static func actionData(for binding: ControlBinding, reportID: UInt8) -> [UInt8] {
        switch binding.kind {
        case .macro:
            return binding.sequence.flatMap { [$0.modifiers.rawValue, $0.key.rawValue] }
        case .media:
            let bytes = mediaBytes(binding.mediaAction, reportID: reportID)
            return [0, bytes.0, bytes.1, 0]
        case .mouse:
            let bytes = mouseBytes(binding.mouseAction)
            return [bytes.button, 0, 0, bytes.scroll, 0, 0]
        case .disabled:
            return []
        }
    }

    private static func mediaBytes(_ action: MediaAction, reportID: UInt8) -> (UInt8, UInt8) {
        if reportID == 2 {
            switch action {
            case .playPause: (0, 4)
            case .nextTrack: (0, 10)
            case .previousTrack: (0, 11)
            case .mute: (0, 1)
            case .volumeUp: (64, 0)
            case .volumeDown: (128, 0)
            }
        } else {
            switch action {
            case .playPause: (64, 0)
            case .nextTrack: (0, 1)
            case .previousTrack: (128, 0)
            case .mute: (4, 0)
            case .volumeUp: (2, 0)
            case .volumeDown: (1, 0)
            }
        }
    }

    private static func mouseBytes(_ action: MouseAction) -> (button: UInt8, scroll: UInt8) {
        switch action {
        case .leftClick: (1, 0)
        case .rightClick: (2, 0)
        case .middleClick: (4, 0)
        case .scrollUp: (0, 1)
        case .scrollDown: (0, 0xFF)
        }
    }

    private static func controlIsValid(_ control: PadControlID, for profile: DeviceProfile) -> Bool {
        switch control {
        case .key(let number): (1...profile.keyCount).contains(number)
        case .knobLeft(let number), .knobPush(let number), .knobRight(let number):
            (1...profile.knobCount).contains(number)
        }
    }
}
