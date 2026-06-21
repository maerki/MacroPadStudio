import SwiftUI

struct DeviceCanvasView: View {
    @EnvironmentObject private var model: AppModel
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.profile.name)
                        .font(.headline)
                    Text("\(model.profile.keyCount) keys • \(model.profile.knobCount) \(model.profile.knobCount == 1 ? "knob" : "knobs")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: model.canWriteToDevice ? "cable.connector" : (model.isHardwareConnected ? "antenna.radiowaves.left.and.right" : "play.rectangle"))
                    .foregroundStyle(model.canWriteToDevice ? .green : .secondary)
            }
            .padding(.horizontal, 22)

            LayerPicker()
                .padding(.horizontal, 22)

            Spacer(minLength: 0)

            deviceControls

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Image(systemName: "hand.tap")
                Text("Select a key or knob to edit it")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)

            LayerLightingPanel()
                .padding(.horizontal, 22)
                .padding(.bottom, 20)
        }
        .padding(.top, 20)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }

    @ViewBuilder
    private var deviceControls: some View {
        if model.profile.keyCount == 3, model.profile.knobCount == 1 {
            HStack(spacing: 10) {
                ForEach(1...3, id: \.self) { number in
                    PadKeyButton(number: number)
                        .frame(width: 64)
                }
                KnobControl(number: 1)
            }
            .padding(16)
            .background(deviceBody)
            .padding(.horizontal, 10)
        } else {
            VStack(spacing: 18) {
                HStack(spacing: 18) {
                    ForEach(1...max(1, model.profile.knobCount), id: \.self) { number in
                        KnobControl(number: number)
                    }
                }
                .frame(maxWidth: .infinity)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(1...model.profile.keyCount, id: \.self) { number in
                        PadKeyButton(number: number)
                    }
                }
            }
            .padding(24)
            .background(deviceBody)
            .padding(.horizontal, 26)
        }
    }

    private var deviceBody: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color(.sRGB, red: 0.075, green: 0.08, blue: 0.09, opacity: 1))
            .shadow(color: .black.opacity(0.28), radius: 18, y: 12)
    }
}

private struct LayerPicker: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Layer")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("Layer", selection: Binding(
                get: { model.activeLayerIndex },
                set: { model.selectLayer($0) }
            )) {
                ForEach(model.configuration.layers) { layer in
                    Text("Layer \(layer.id + 1)")
                        .tag(layer.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .controlSize(.large)
            .frame(minHeight: 34)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Active layer")
        }
    }
}

private struct LayerLightingPanel: View {
    @EnvironmentObject private var model: AppModel

    private let colorColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Layer \(model.activeLayer.id + 1) Lighting", systemImage: "lightbulb")
                        .font(.headline)
                    Text("Applies to the entire \(model.activeLayer.name) layer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Layer Lighting", isOn: lightingEnabledBinding)
                    .labelsHidden()
            }

            Picker("Effect", selection: ledModeBinding) {
                ForEach(0..<model.profile.ledModeCount, id: \.self) { mode in
                    Text(mode == 0 ? "Static" : "Effect \(mode + 1)").tag(UInt8(mode))
                }
            }
            .disabled(!model.activeLayer.lighting.enabled)

            LazyVGrid(columns: colorColumns, spacing: 8) {
                ForEach(LEDColor.allCases) { color in
                    Button {
                        model.updateLighting { $0.color = color }
                    } label: {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(color.color)
                            .frame(height: 30)
                            .overlay {
                                if model.activeLayer.lighting.color == color {
                                    Image(systemName: "checkmark")
                                        .fontWeight(.bold)
                                        .foregroundStyle(color == .yellow ? .black : .white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.profile.supportsColor || !model.activeLayer.lighting.enabled)
                    .help("Set Layer \(model.activeLayer.id + 1) lighting to \(color.name)")
                    .accessibilityLabel("\(color.name), Layer \(model.activeLayer.id + 1) lighting")
                }
            }
        }
    }

    private var lightingEnabledBinding: Binding<Bool> {
        Binding(get: { model.activeLayer.lighting.enabled }, set: { value in
            model.updateLighting { $0.enabled = value }
        })
    }

    private var ledModeBinding: Binding<UInt8> {
        Binding(get: { model.activeLayer.lighting.mode }, set: { value in
            model.updateLighting { $0.mode = value }
        })
    }
}

private struct PadKeyButton: View {
    @EnvironmentObject private var model: AppModel
    let number: Int

    private var binding: ControlBinding {
        model.activeLayer.bindings[.key(number)] ?? ControlBinding()
    }

    private var isSelected: Bool { model.selectedControl == .key(number) }

    var body: some View {
        Button {
            model.selectedControl = .key(number)
        } label: {
            VStack(spacing: 5) {
                Text("\(number)")
                    .font(.title3.weight(.semibold))
                Text(actionLabel)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 76)
            .contentShape(Rectangle())
        }
        .buttonStyle(PadControlButtonStyle(isSelected: isSelected, color: model.activeLayer.lighting.color.color))
    }

    private var actionLabel: String {
        switch binding.kind {
        case .macro: binding.sequence.first?.displayName ?? "Unassigned"
        case .media: binding.mediaAction.rawValue
        case .mouse: binding.mouseAction.rawValue
        case .disabled: "Disabled"
        }
    }
}

private struct KnobControl: View {
    @EnvironmentObject private var model: AppModel
    let number: Int

    var body: some View {
        ZStack {
            Button {
                if model.selectedControl.knobNumber != number {
                    model.selectedControl = .knobPush(number)
                }
            } label: {
                Circle()
                    .fill(Color(.sRGB, red: 0.12, green: 0.13, blue: 0.14, opacity: 1))
                    .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
                    .shadow(color: .black.opacity(0.55), radius: 8, y: 5)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Knob \(number)")
            .help("Select Knob \(number)")

            Capsule()
                .fill(.white.opacity(0.8))
                .frame(width: 3, height: 15)
                .offset(y: -24)
                .allowsHitTesting(false)
        }
        .frame(width: 88, height: 88)
        .overlay {
            Circle()
                .stroke(
                    model.selectedControl.knobNumber == number
                        ? model.activeLayer.lighting.color.color
                        : .clear,
                    lineWidth: 4
                )
                .allowsHitTesting(false)
        }
    }
}

private struct PadControlButtonStyle: ButtonStyle {
    let isSelected: Bool
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.sRGB, red: 0.13, green: 0.14, blue: 0.15, opacity: 1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? color : .white.opacity(0.1), lineWidth: isSelected ? 3 : 1)
                    )
                    .shadow(color: isSelected ? color.opacity(0.35) : .black.opacity(0.4), radius: isSelected ? 8 : 4, y: 3)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}
