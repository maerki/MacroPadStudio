import XCTest
@testable import MacroPadStudio

@MainActor
final class HardwareWriteTests: XCTestCase {
    func testSetLayerOneKeysToWSD() async throws {
        let gateURL = URL(fileURLWithPath: "/tmp/macropadstudio-hardware-wsd-token")
        let expectedToken = "SET-LAYER-1-WSD-1189-8840"
        let suppliedToken = try? String(contentsOf: gateURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard suppliedToken == expectedToken else {
            throw XCTSkip("Create the one-use WSD token to update Layer 1 on real hardware.")
        }
        try FileManager.default.removeItem(at: gateURL)

        let service = HIDDeviceService()
        let storeRoot = FileManager.default.temporaryDirectory
            .appending(path: "MacroPadStudioHardwareWSD", directoryHint: .isDirectory)
        let model = AppModel(hidService: service, store: ConfigurationStore(baseURL: storeRoot))
        defer { service.stop() }

        let deadline = Date().addingTimeInterval(5)
        while !model.canWriteToDevice, Date() < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        guard case .hardware(let connected) = model.mode else {
            XCTFail("The supported USB configuration interface was not detected.")
            return
        }
        guard connected.access == .writableUSB else {
            XCTFail("The WSD hardware write token is only valid for the supported USB configuration interface.")
            return
        }

        let currentReports = try await service.readConfigurationReports()
        model.configuration = try MacroPadProtocolDecoder.applying(
            currentReports,
            to: model.configuration,
            profile: connected.profile
        )
        try await Task.sleep(for: .seconds(1))

        let assignments: [(PadControlID, HIDKey)] = [
            (.key(1), .w),
            (.key(2), .s),
            (.key(3), .d)
        ]
        model.selectLayer(0)
        for (control, key) in assignments {
            model.selectedControl = control
            model.updateSelectedBinding { binding in
                binding = ControlBinding(
                    kind: .macro,
                    sequence: [Keystroke(key: key, modifiers: [])],
                    interKeyDelayMilliseconds: 0
                )
            }
        }

        XCTAssertEqual(model.changeCount, 3)
        model.requestApply()
        XCTAssertTrue(model.showingApplyReview)
        print("WRITE_REVIEW Layer 1: Key 1 = W, Key 2 = S, Key 3 = D")
        model.applyChanges()
        XCTAssertEqual(model.changeCount, 0, model.notice?.message ?? "No apply result")

        let verificationReports = try await service.readConfigurationReports()
        let verified = try MacroPadProtocolDecoder.applying(
            verificationReports,
            to: model.configuration,
            profile: connected.profile
        )
        var verifiedAssignments: [(PadControlID, HIDKey)] = []
        for (control, expectedKey) in assignments {
            let binding = try XCTUnwrap(verified.layers[0].bindings[control])
            XCTAssertEqual(binding.kind, .macro)
            XCTAssertEqual(binding.sequence.map(\.key), [expectedKey])
            XCTAssertEqual(binding.sequence.map(\.modifiers), [[]])
            XCTAssertEqual(binding.interKeyDelayMilliseconds, 0)
            if binding.kind == .macro,
               binding.sequence.map(\.key) == [expectedKey],
               binding.sequence.map(\.modifiers) == [[]],
               binding.interKeyDelayMilliseconds == 0 {
                verifiedAssignments.append((control, expectedKey))
            }
        }
        if verifiedAssignments.count == assignments.count {
            print("WRITE_VERIFIED Layer 1: Key 1 = W, Key 2 = S, Key 3 = D")
        }
    }

    func testReadCompleteProfileFromConnectedDevice() async throws {
        let gateURL = URL(fileURLWithPath: "/tmp/macropadstudio-hardware-read-token")
        let expectedToken = "READ-COMPLETE-PROFILE-1189-8840"
        let suppliedToken = try? String(contentsOf: gateURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard suppliedToken == expectedToken else {
            throw XCTSkip("Create the one-use hardware-read token to perform a real configuration read.")
        }
        try FileManager.default.removeItem(at: gateURL)

        let service = HIDDeviceService()
        service.start()
        defer { service.stop() }

        let deadline = Date().addingTimeInterval(5)
        while service.connectedDevice == nil, Date() < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }

        let connected = try XCTUnwrap(service.connectedDevice)
        XCTAssertEqual(connected.access, .writableUSB)
        XCTAssertEqual(connected.profile, .miniKeyboardExtended)
        XCTAssertEqual(connected.reportID, 3)

        let reports = try await service.readConfigurationReports()
        XCTAssertEqual(reports.count, 72)
        XCTAssertEqual(Set(reports.map(\.reportID)), [3])

        let decoded = try MacroPadProtocolDecoder.applying(
            reports,
            to: .starter(for: connected.profile),
            profile: connected.profile
        )
        printConfiguration(decoded, profile: connected.profile)
        XCTAssertEqual(decoded.layers.count, 3)
        for layer in decoded.layers {
            XCTAssertNotNil(layer.bindings[.key(1)])
            XCTAssertNotNil(layer.bindings[.key(2)])
            XCTAssertNotNil(layer.bindings[.key(3)])
            XCTAssertNotNil(layer.bindings[.knobLeft(1)])
            XCTAssertNotNil(layer.bindings[.knobPush(1)])
            XCTAssertNotNil(layer.bindings[.knobRight(1)])
        }
    }

    private func printConfiguration(_ configuration: PadConfiguration, profile: DeviceProfile) {
        let controls: [PadControlID] = [
            .key(1), .key(2), .key(3),
            .knobLeft(1), .knobPush(1), .knobRight(1)
        ]
        print("CURRENT_CONFIG_BEGIN \(profile.vendorID):\(profile.productID)")
        for layer in configuration.layers {
            print("LAYER \(layer.id + 1)")
            for control in controls {
                guard let binding = layer.bindings[control] else { continue }
                print("CONTROL \(control.title): \(summary(of: binding))")
            }
        }
        print("CURRENT_CONFIG_END")
    }

    private func summary(of binding: ControlBinding) -> String {
        switch binding.kind {
        case .macro:
            let sequence = binding.sequence.map(\.displayName).joined(separator: " then ")
            let delay = binding.interKeyDelayMilliseconds > 0
                ? " (\(binding.interKeyDelayMilliseconds) ms delay)"
                : ""
            return "Macro: \(sequence.isEmpty ? "Empty" : sequence)\(delay)"
        case .media:
            return "Media: \(binding.mediaAction.rawValue)"
        case .mouse:
            return "Mouse: \(binding.mouseAction.rawValue)"
        case .disabled:
            return "Disabled"
        }
    }

    func testWriteCompleteProfileToConnectedDevice() throws {
        let gateURL = URL(fileURLWithPath: "/tmp/macropadstudio-hardware-write-token")
        let expectedToken = "WRITE-COMPLETE-PROFILE-1189-8840"
        let suppliedToken = try? String(contentsOf: gateURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard suppliedToken == expectedToken else {
            throw XCTSkip("Create the one-use hardware-write token to perform real HID writes.")
        }
        try FileManager.default.removeItem(at: gateURL)

        let service = HIDDeviceService()
        let storeRoot = FileManager.default.temporaryDirectory
            .appending(path: "MacroPadStudioHardwareWrite", directoryHint: .isDirectory)
        let model = AppModel(hidService: service, store: ConfigurationStore(baseURL: storeRoot))
        defer { service.stop() }

        let deadline = Date().addingTimeInterval(5)
        while !model.canWriteToDevice, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        guard case .hardware(let device) = model.mode else {
            XCTFail("The supported USB configuration interface was not detected.")
            return
        }
        XCTAssertEqual(device.access, .writableUSB)
        XCTAssertEqual(device.profile.productID, 0x8840)
        XCTAssertEqual(device.profile.interfaceNumber, 0)
        XCTAssertEqual(device.reportID, 3)

        for layerIndex in model.configuration.layers.indices {
            model.selectLayer(layerIndex)
            for key in 1...model.profile.keyCount {
                model.selectedControl = .key(key)
                model.updateSelectedBinding { _ in }
            }
            for knob in 1...model.profile.knobCount {
                for control in [
                    PadControlID.knobLeft(knob),
                    .knobPush(knob),
                    .knobRight(knob)
                ] {
                    model.selectedControl = control
                    model.updateSelectedBinding { _ in }
                }
            }
            model.updateLighting { _ in }
        }

        XCTAssertEqual(model.changeCount, 21)
        model.requestApply()
        XCTAssertTrue(model.showingApplyReview)
        model.applyChanges()

        let applyResult = model.notice?.message ?? "No apply result was reported."
        XCTAssertEqual(model.changeCount, 0, applyResult)
        XCTAssertFalse(model.showingApplyReview)
        XCTAssertTrue(model.notice?.message.contains("Configuration written") == true, applyResult)
        XCTAssertTrue(model.canWriteToDevice)
    }
}
