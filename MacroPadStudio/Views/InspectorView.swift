import SwiftUI

struct ApplyReviewView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Review Changes", systemImage: "checklist")
                    .font(.title2.weight(.semibold))
                Text(model.isHardwareConnected
                     ? "These reports will be written directly to \(model.connectionTitle). Keep the device connected until the operation finishes."
                     : "Demo mode applies these changes only to the local profile.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)

            Divider()

            List {
                ForEach(model.dirtyControls.sorted(by: { $0.id < $1.id })) { location in
                    HStack {
                        Image(systemName: "keyboard")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading) {
                            Text(location.control.title)
                            Text(model.configuration.layers[location.layer].name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("Action changed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(model.dirtyLightingLayers.sorted(), id: \.self) { layer in
                    HStack {
                        Image(systemName: "lightbulb")
                            .foregroundStyle(.orange)
                        Text(model.configuration.layers[layer].name)
                        Spacer()
                        Text("Lighting changed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.inset)

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(model.isHardwareConnected ? "Apply to Device" : "Apply Demo Changes") {
                    model.applyChanges()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(18)
        }
        .frame(width: 560, height: 460)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section("Safety") {
                Toggle("Developer mode", isOn: $model.developerMode)
                Text("Developer mode exposes protocol details but never removes the write confirmation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Supported Devices") {
                ForEach(DeviceProfile.supported) { profile in
                    HStack {
                        Text(profile.name)
                        Spacer()
                        Text(String(format: "%04X:%04X", profile.vendorID, profile.productID))
                            .monospaced()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 520, height: 430)
    }
}
