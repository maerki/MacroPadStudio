import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    struct BindingLocation: Hashable, Identifiable {
        let layer: Int
        let control: PadControlID
        var id: String { "\(layer)-\(control.id)" }
    }

    enum Mode: Equatable {
        case demo
        case hardware(ConnectedHIDDevice)
    }

    struct Notice: Identifiable, Equatable {
        enum Kind { case success, warning, error }
        let id = UUID()
        let kind: Kind
        let message: String

        static func == (lhs: Notice, rhs: Notice) -> Bool {
            lhs.kind == rhs.kind && lhs.message == rhs.message
        }
    }

    @Published private(set) var mode: Mode = .demo
    @Published var configuration: PadConfiguration
    @Published var selectedControl: PadControlID = .key(2)
    @Published var activeLayerIndex = 0
    @Published private(set) var dirtyControls: Set<BindingLocation> = []
    @Published private(set) var dirtyLightingLayers: Set<Int> = []
    @Published var showingApplyReview = false
    @Published var showingReadReview = false
    @Published private(set) var isReadingConfiguration = false
    @Published var notice: Notice?
    @Published var developerMode = false

    private let hidService: HIDDeviceService
    private let store: ConfigurationStore

    convenience init() {
        self.init(hidService: HIDDeviceService(), store: ConfigurationStore())
    }

    init(hidService: HIDDeviceService, store: ConfigurationStore) {
        self.hidService = hidService
        self.store = store
        configuration = (try? store.load(for: .demo)) ?? .starter(for: .demo)
        hidService.onConnectionChanged = { [weak self] device in
            self?.handleConnection(device)
        }
        hidService.start()
    }

    var profile: DeviceProfile {
        switch mode {
        case .demo: .demo
        case .hardware(let device): device.profile
        }
    }

    var connectionTitle: String {
        switch mode {
        case .demo: "Demo MacroPad"
        case .hardware(let device): device.productName
        }
    }

    var connectionDetail: String {
        switch mode {
        case .demo: "3 keys + 1 knob • Preview mode"
        case .hardware(let device):
            if device.isConfigurable {
                String(format: "%@ • %04X:%04X", device.transport, device.profile.vendorID, device.profile.productID)
            } else {
                "Bluetooth • Connect USB to apply changes"
            }
        }
    }

    var isHardwareConnected: Bool {
        if case .hardware = mode { return true }
        return false
    }

    var canWriteToDevice: Bool {
        switch mode {
        case .demo: false
        case .hardware(let device): device.isConfigurable
        }
    }

    var isBluetoothReadOnly: Bool {
        switch mode {
        case .demo: false
        case .hardware(let device): device.isBluetoothReadOnly
        }
    }

    var canReadFromDevice: Bool {
        guard !isReadingConfiguration else { return false }
        guard case .hardware(let device) = mode else { return true }
        return device.isConfigurable && device.profile == .miniKeyboardExtended && device.reportID == 3
    }

    var activeLayer: LayerConfiguration {
        configuration.layers[activeLayerIndex]
    }

    var selectedBinding: ControlBinding {
        activeLayer.bindings[selectedControl] ?? ControlBinding()
    }

    var canApply: Bool {
        let hasChanges = !dirtyControls.isEmpty || !dirtyLightingLayers.isEmpty
        guard !isReadingConfiguration else { return false }
        return switch mode {
        case .demo: hasChanges
        case .hardware(let device): hasChanges && device.isConfigurable
        }
    }

    var changeCount: Int { dirtyControls.count + dirtyLightingLayers.count }

    func selectLayer(_ index: Int) {
        guard configuration.layers.indices.contains(index) else { return }
        activeLayerIndex = index
    }

    func updateSelectedBinding(_ mutate: (inout ControlBinding) -> Void) {
        guard configuration.layers.indices.contains(activeLayerIndex) else { return }
        var binding = selectedBinding
        mutate(&binding)
        configuration.layers[activeLayerIndex].bindings[selectedControl] = binding
        dirtyControls.insert(BindingLocation(layer: activeLayerIndex, control: selectedControl))
        persistDraft()
    }

    func updateLighting(_ mutate: (inout LayerLighting) -> Void) {
        guard configuration.layers.indices.contains(activeLayerIndex) else { return }
        mutate(&configuration.layers[activeLayerIndex].lighting)
        dirtyLightingLayers.insert(activeLayerIndex)
        persistDraft()
    }

    func addKeystroke(key: HIDKey = .returnKey, modifiers: HIDModifier = []) {
        updateSelectedBinding { binding in
            guard binding.sequence.count < profile.maxSequenceLength else { return }
            binding.sequence.append(Keystroke(key: key, modifiers: modifiers))
        }
    }

    func removeKeystroke(id: UUID) {
        updateSelectedBinding { $0.sequence.removeAll { $0.id == id } }
    }

    func moveKeystrokeUp(id: UUID) {
        updateSelectedBinding { binding in
            guard let index = binding.sequence.firstIndex(where: { $0.id == id }), index > 0 else { return }
            binding.sequence.swapAt(index, index - 1)
        }
    }

    func moveKeystrokeDown(id: UUID) {
        updateSelectedBinding { binding in
            guard let index = binding.sequence.firstIndex(where: { $0.id == id }), index + 1 < binding.sequence.count else { return }
            binding.sequence.swapAt(index, index + 1)
        }
    }

    func requestApply() {
        guard canApply else { return }
        showingApplyReview = true
    }

    func applyChanges() {
        showingApplyReview = false
        if case .demo = mode {
            dirtyControls.removeAll()
            dirtyLightingLayers.removeAll()
            notice = Notice(kind: .success, message: "Demo changes applied locally.")
            persistDraft()
            return
        }

        guard case .hardware(let connected) = mode else { return }
        guard connected.isConfigurable else {
            notice = Notice(kind: .warning, message: "This connection cannot apply changes.")
            return
        }
        do {
            for location in dirtyControls.sorted(by: { $0.id < $1.id }) {
                guard let binding = configuration.layers[location.layer].bindings[location.control] else { continue }
                let reports = try MacroPadProtocolEncoder.reports(
                    for: location.control,
                    layer: location.layer,
                    binding: binding,
                    profile: connected.profile,
                    reportID: connected.reportID
                )
                for report in reports { try hidService.write(report) }
            }
            for layerIndex in dirtyLightingLayers.sorted() {
                let reports = try MacroPadProtocolEncoder.lightingReport(
                    layer: layerIndex,
                    lighting: configuration.layers[layerIndex].lighting,
                    profile: connected.profile,
                    reportID: connected.reportID
                )
                for report in reports { try hidService.write(report) }
            }
            dirtyControls.removeAll()
            dirtyLightingLayers.removeAll()
            notice = Notice(kind: .success, message: "Configuration written to \(connected.productName).")
            persistDraft()
        } catch {
            notice = Notice(kind: .error, message: error.localizedDescription)
        }
    }

    func readFromDevice() {
        if case .demo = mode {
            configuration = (try? store.load(for: profile)) ?? .starter(for: profile)
            dirtyControls.removeAll()
            dirtyLightingLayers.removeAll()
            notice = Notice(kind: .success, message: "Reloaded the saved demo configuration.")
        } else {
            guard canReadFromDevice else {
                notice = Notice(kind: .warning, message: "Configuration reading is not supported for this connection.")
                return
            }
            showingReadReview = true
        }
    }

    func confirmReadFromDevice() {
        showingReadReview = false
        guard case .hardware(let connected) = mode, canReadFromDevice else { return }
        isReadingConfiguration = true
        notice = nil

        Task {
            defer { isReadingConfiguration = false }
            do {
                let reports = try await hidService.readConfigurationReports()
                configuration = try MacroPadProtocolDecoder.applying(
                    reports,
                    to: configuration,
                    profile: connected.profile
                )
                dirtyControls.removeAll()
                persistDraft()
                let assignmentCount = connected.profile.layerCount * (connected.profile.keyCount + connected.profile.knobCount * 3)
                notice = Notice(
                    kind: .success,
                    message: "Read \(assignmentCount) assignments from \(connected.productName). Layer lighting was preserved."
                )
            } catch {
                notice = Notice(kind: .error, message: error.localizedDescription)
            }
        }
    }

    func resetSelectedControl() {
        updateSelectedBinding { $0 = ControlBinding.defaultShortcut }
    }

    private func handleConnection(_ device: ConnectedHIDDevice?) {
        let nextProfile: DeviceProfile
        if let device {
            mode = .hardware(device)
            nextProfile = device.profile
            notice = Notice(kind: .success, message: "Connected to \(device.productName).")
        } else {
            mode = .demo
            nextProfile = .demo
            notice = Notice(kind: .warning, message: "Device disconnected. Switched to demo mode.")
        }
        configuration = (try? store.load(for: nextProfile)) ?? .starter(for: nextProfile)
        activeLayerIndex = 0
        selectedControl = .key(min(2, nextProfile.keyCount))
        dirtyControls.removeAll()
        dirtyLightingLayers.removeAll()
    }

    private func persistDraft() {
        do {
            try store.save(configuration)
        } catch {
            notice = Notice(kind: .error, message: "Could not save the local draft: \(error.localizedDescription)")
        }
    }
}
