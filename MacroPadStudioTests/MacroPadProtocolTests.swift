import XCTest
@testable import MacroPadStudio

final class MacroPadProtocolTests: XCTestCase {
    private var extendedProfile: DeviceProfile {
        DeviceProfile.supported.first { $0.deviceProtocol == .extended }!
    }

    func testExtendedMacroReportMatchesKnownLayout() throws {
        let binding = ControlBinding(
            sequence: [
                Keystroke(key: .f5, modifiers: [.leftCommand, .leftShift]),
                Keystroke(key: .returnKey, modifiers: [])
            ],
            interKeyDelayMilliseconds: 100
        )

        let reports = try MacroPadProtocolEncoder.reports(
            for: .key(2), layer: 0, binding: binding, profile: extendedProfile, reportID: 0
        )

        XCTAssertEqual(reports.count, 1)
        let payload = reports[0].payload
        XCTAssertEqual(payload.count, 64)
        XCTAssertEqual(Array(payload[0...5]), [0xFE, 0x02, 0x01, 0x01, 0x64, 0x00])
        XCTAssertEqual(Array(payload[6...8]), [0x00, 0x00, 0x00])
        XCTAssertEqual(payload[9], 2)
        XCTAssertEqual(Array(payload[10...13]), [0x0A, 0x3E, 0x00, 0x28])
    }

    func testExtendedMediaReportUsesReportIDTwoMapping() throws {
        var binding = ControlBinding()
        binding.kind = .media
        binding.mediaAction = .volumeUp

        let report = try XCTUnwrap(MacroPadProtocolEncoder.reports(
            for: .knobRight(1), layer: 0, binding: binding, profile: extendedProfile, reportID: 2
        ).first)

        XCTAssertEqual(report.payload[0], 0xFE)
        XCTAssertEqual(report.payload[1], 16)
        XCTAssertEqual(report.payload[3], 0x02)
        XCTAssertEqual(Array(report.payload[10...13]), [0, 64, 0, 0])
    }

    func testLegacyMacroEndsWithCommitReport() throws {
        var binding = ControlBinding.defaultShortcut
        binding.interKeyDelayMilliseconds = 0
        let profile = try XCTUnwrap(DeviceProfile.supported.first { $0.deviceProtocol == .legacy })

        let reports = try MacroPadProtocolEncoder.reports(
            for: .key(1), layer: 0, binding: binding, profile: profile, reportID: 0
        )

        XCTAssertEqual(reports.count, binding.sequence.count + 2)
        XCTAssertEqual(Array(reports.last!.payload[0...1]), [0xAA, 0xAA])
    }

    func testLightingIsLayerScoped() throws {
        let lighting = LayerLighting(enabled: true, color: .purple, mode: 2, brightness: 0.5)
        let report = try XCTUnwrap(MacroPadProtocolEncoder.lightingReport(
            layer: 2, lighting: lighting, profile: extendedProfile, reportID: 0
        ).first)

        XCTAssertEqual(report.payload[1], 0xB0)
        XCTAssertEqual(report.payload[2], 3)
        XCTAssertEqual(report.payload[10], 3)
        XCTAssertEqual(report.payload[11], 0x72)
    }

    func testSequenceLengthIsValidated() {
        var binding = ControlBinding()
        binding.sequence = (0...extendedProfile.maxSequenceLength).map { _ in
            Keystroke(key: .a, modifiers: [])
        }

        XCTAssertThrowsError(try MacroPadProtocolEncoder.reports(
            for: .key(1), layer: 0, binding: binding, profile: extendedProfile, reportID: 0
        )) { error in
            XCTAssertEqual(error as? ProtocolEncodingError, .sequenceTooLong(maximum: extendedProfile.maxSequenceLength))
        }
    }

    func testExtendedReportsTranslateAppLayerIndicesToDeviceLayerNumbers() throws {
        let binding = ControlBinding(sequence: [Keystroke(key: .w, modifiers: [])])

        let reports = try (0..<extendedProfile.layerCount).map { layer in
            try XCTUnwrap(MacroPadProtocolEncoder.reports(
                for: .key(1), layer: layer, binding: binding,
                profile: extendedProfile, reportID: 3
            ).first)
        }

        XCTAssertEqual(reports.map { $0.payload[2] }, [1, 2, 3])
    }

    func testDefaultProfileMatchesConnectedMiniKeyboardLayout() {
        XCTAssertEqual(DeviceProfile.demo, .miniKeyboardExtended)
        XCTAssertEqual(DeviceProfile.miniKeyboardExtended.keyCount, 3)
        XCTAssertEqual(DeviceProfile.miniKeyboardExtended.knobCount, 1)
        XCTAssertEqual(DeviceProfile.miniKeyboardExtended.productID, 0x8840)
        XCTAssertEqual(DeviceProfile.miniKeyboardExtended.interfaceNumber, 0)
        XCTAssertEqual(DeviceProfile.miniKeyboardExtended.deviceProtocol, .extended)
    }

    func testBluetoothMiniKeyboardIsReadOnlyUntilAConfigurationInterfaceIsVerified() {
        let device = ConnectedHIDDevice(
            profile: .miniKeyboardExtended,
            productName: "MINI_KEYBOARD",
            reportID: 3,
            access: .bluetoothReadOnly,
            transport: "Bluetooth Low Energy"
        )

        XCTAssertFalse(device.isConfigurable)
        XCTAssertTrue(device.isBluetoothReadOnly)
    }

    func testKnobControlsExposeTheirPhysicalKnobNumber() {
        XCTAssertNil(PadControlID.key(1).knobNumber)
        XCTAssertEqual(PadControlID.knobLeft(2).knobNumber, 2)
        XCTAssertEqual(PadControlID.knobPush(2).knobNumber, 2)
        XCTAssertEqual(PadControlID.knobRight(2).knobNumber, 2)
    }

    func testLegacyKnobUsesKnownActionNumbers() throws {
        var binding = ControlBinding()
        binding.kind = .media
        binding.mediaAction = .volumeUp

        let reports = try MacroPadProtocolEncoder.reports(
            for: .knobRight(1), layer: 0, binding: binding,
            profile: .legacyMini, reportID: 0
        )

        XCTAssertEqual(reports.first?.payload[0], 15)
    }

    func testExtendedKnobUsesVerifiedFifteenKeyFirmwareSlots() throws {
        var binding = ControlBinding()
        binding.kind = .media

        let left = try XCTUnwrap(MacroPadProtocolEncoder.reports(
            for: .knobLeft(1), layer: 0, binding: binding,
            profile: .miniKeyboardExtended, reportID: 3
        ).first)
        let push = try XCTUnwrap(MacroPadProtocolEncoder.reports(
            for: .knobPush(1), layer: 0, binding: binding,
            profile: .miniKeyboardExtended, reportID: 3
        ).first)
        let right = try XCTUnwrap(MacroPadProtocolEncoder.reports(
            for: .knobRight(1), layer: 0, binding: binding,
            profile: .miniKeyboardExtended, reportID: 3
        ).first)

        XCTAssertEqual([left.payload[1], push.payload[1], right.payload[1]], [18, 17, 16])
    }

    func testConfigurationReadRequestMatchesVendorProtocol() throws {
        let requests = try MacroPadProtocolDecoder.configurationReadRequests(
            profile: .miniKeyboardExtended,
            reportID: 3
        )

        XCTAssertEqual(requests.count, 3)
        XCTAssertEqual(requests.map(\.reportID), [3, 3, 3])
        XCTAssertEqual(Array(requests[0].payload[0...3]), [0xFA, 0x0F, 0x03, 0x01])
        XCTAssertEqual(Array(requests[2].payload[0...3]), [0xFA, 0x0F, 0x03, 0x03])
    }

    func testConfigurationDecoderReadsPhysicalControlsAndPreservesLighting() throws {
        var base = PadConfiguration.starter(for: .miniKeyboardExtended)
        base.layers[0].lighting = LayerLighting(enabled: true, color: .purple, mode: 2, brightness: 0.4)
        var reports = configurationFixture()
        setRecord(&reports, layer: 1, action: 1, kind: 1, delay: 100, data: [0x08, 0x04])
        setRecord(&reports, layer: 1, action: 2, kind: 2, data: [0, 0x02, 0, 0])
        setRecord(&reports, layer: 1, action: 3, kind: 3, data: [0, 0, 0, 0xFF, 0, 0])
        setRecord(&reports, layer: 1, action: 18, kind: 0)
        setRecord(&reports, layer: 1, action: 17, kind: 1, data: [0, 0x28])
        setRecord(&reports, layer: 1, action: 16, kind: 2, data: [0, 0x01, 0, 0])

        let decoded = try MacroPadProtocolDecoder.applying(
            reports,
            to: base,
            profile: .miniKeyboardExtended
        )

        XCTAssertEqual(decoded.layers[0].bindings[.key(1)]?.sequence.first?.key, .a)
        XCTAssertEqual(decoded.layers[0].bindings[.key(1)]?.sequence.first?.modifiers, .leftCommand)
        XCTAssertEqual(decoded.layers[0].bindings[.key(1)]?.interKeyDelayMilliseconds, 100)
        XCTAssertEqual(decoded.layers[0].bindings[.key(2)]?.mediaAction, .volumeUp)
        XCTAssertEqual(decoded.layers[0].bindings[.key(3)]?.mouseAction, .scrollDown)
        XCTAssertEqual(decoded.layers[0].bindings[.knobLeft(1)]?.kind, .disabled)
        XCTAssertEqual(decoded.layers[0].bindings[.knobPush(1)]?.sequence.first?.key, .returnKey)
        XCTAssertEqual(decoded.layers[0].bindings[.knobRight(1)]?.mediaAction, .volumeDown)
        XCTAssertEqual(decoded.layers[0].lighting, base.layers[0].lighting)
    }

    func testConfigurationDecoderRejectsIncompleteResponse() {
        XCTAssertThrowsError(try MacroPadProtocolDecoder.applying(
            Array(configurationFixture().dropLast()),
            to: .starter(for: .miniKeyboardExtended),
            profile: .miniKeyboardExtended
        )) { error in
            XCTAssertEqual(
                error as? ProtocolDecodingError,
                .incompleteResponse(expected: 72, actual: 71)
            )
        }
    }

    func testReportIDRemainsSeparateFromPayload() {
        let payload = [UInt8](repeating: 0xAB, count: 64)
        let report = HIDReport(reportID: 3, payload: payload)
        XCTAssertEqual(report.reportID, 3)
        XCTAssertEqual(report.payload.count, 64)
        XCTAssertEqual(report.payload.first, 0xAB)
    }

    private func configurationFixture() -> [HIDInputReport] {
        (1...3).flatMap { layer in
            let actions = Array(1...15) + [18, 17, 16, 21, 20, 19, 24, 23, 22]
            return actions.map { action in
                var payload = [UInt8](repeating: 0, count: 64)
                payload[0] = 0xFA
                payload[1] = UInt8(action)
                payload[2] = UInt8(layer)
                payload[3] = 1
                payload[9] = 1
                payload[11] = HIDKey.a.rawValue
                return HIDInputReport(reportID: 3, payload: payload)
            }
        }
    }

    private func setRecord(
        _ reports: inout [HIDInputReport],
        layer: Int,
        action: Int,
        kind: UInt8,
        delay: UInt16 = 0,
        data: [UInt8] = []
    ) {
        let layerStart = (layer - 1) * 24
        let index = reports[layerStart..<(layerStart + 24)].firstIndex {
            $0.payload[1] == UInt8(action)
        }!
        var payload = reports[index].payload
        payload[3] = kind
        payload[4] = UInt8(truncatingIfNeeded: delay)
        payload[5] = UInt8(truncatingIfNeeded: delay >> 8)
        payload[9] = kind == 1 ? UInt8(data.count / 2) : 0
        for (offset, byte) in data.enumerated() { payload[10 + offset] = byte }
        reports[index] = HIDInputReport(reportID: 3, payload: payload)
    }
}
