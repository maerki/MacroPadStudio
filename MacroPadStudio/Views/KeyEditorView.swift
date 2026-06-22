import SwiftUI

struct KeyEditorView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleBar

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if let knobNumber = model.selectedControl.knobNumber {
                        KnobActionSelector(number: knobNumber)
                    }

                    BehaviorSummary()
                    actionTypePicker
                    actionEditor
                }
                .padding(.horizontal, 30)
                .padding(.top, 22)
                .padding(.bottom, 30)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var titleBar: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.selectedControl.title)
                    .font(.largeTitle.weight(.semibold))
                Text(model.activeLayer.name)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            DeviceActionButtons()
        }
        .padding(.horizontal, 30)
        .padding(.top, 20)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var actionTypePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Action Type")
                .font(.headline)
            HStack(spacing: 6) {
                ForEach(ActionKind.allCases) { kind in
                    ActionTypeButton(kind: kind, selected: model.selectedBinding.kind == kind) {
                        model.updateSelectedBinding { $0.kind = kind }
                    }
                }
            }
            .padding(4)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder
    private var actionEditor: some View {
        switch model.selectedBinding.kind {
        case .macro:
            MacroSequenceEditor()
        case .media:
            VStack(alignment: .leading, spacing: 12) {
                Text("Media Action").font(.headline)
                Picker("Media Action", selection: mediaBinding) {
                    ForEach(MediaAction.allCases) { Text($0.rawValue).tag($0) }
                }
                .frame(maxWidth: 320)
                Text("The selected media command is sent when this control is used.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        case .mouse:
            VStack(alignment: .leading, spacing: 12) {
                Text("Mouse Action").font(.headline)
                Picker("Mouse Action", selection: mouseBinding) {
                    ForEach(MouseAction.allCases) { Text($0.rawValue).tag($0) }
                }
                .frame(maxWidth: 320)
                Text("Mouse support varies by firmware version.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        case .disabled:
            ContentUnavailableView(
                "Control Disabled",
                systemImage: "nosign",
                description: Text("This control will not send an action on the active layer.")
            )
            .frame(maxWidth: .infinity, minHeight: 260)
        }
    }

    private var mediaBinding: Binding<MediaAction> {
        Binding(get: { model.selectedBinding.mediaAction }, set: { value in
            model.updateSelectedBinding { $0.mediaAction = value }
        })
    }

    private var mouseBinding: Binding<MouseAction> {
        Binding(get: { model.selectedBinding.mouseAction }, set: { value in
            model.updateSelectedBinding { $0.mouseAction = value }
        })
    }
}

private struct DeviceActionButtons: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            Button {
                model.readFromDevice()
            } label: {
                if model.isReadingConfiguration {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 17, height: 17)
                } else {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 17, weight: .medium))
                }
            }
            .buttonStyle(DeviceActionButtonStyle(kind: .secondary))
            .disabled(!model.canReadFromDevice)
            .help(model.isReadingConfiguration ? "Reading configuration..." : "Read control assignments from the keypad")
            .accessibilityLabel("Read from Device")

            Button {
                model.requestApply()
            } label: {
                Image(systemName: "arrow.up.to.line")
                    .font(.system(size: 17, weight: .medium))
            }
            .buttonStyle(DeviceActionButtonStyle(kind: .primary))
            .disabled(!model.canApply)
            .help(applyHelp)
            .accessibilityLabel("Apply to Device")
        }
    }

    private var applyHelp: String {
        if model.canApply { return "Review and apply \(model.changeCount) changes" }
        if model.changeCount > 0 { return "Connect the keypad over USB to apply changes" }
        return "No changes to apply"
    }
}

private struct DeviceActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    enum Kind {
        case primary
        case secondary
    }

    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 34, height: 34)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor(for: configuration), in: Circle())
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.45)
    }

    private var foregroundColor: Color {
        switch kind {
        case .primary: .white
        case .secondary: .primary
        }
    }

    private func backgroundColor(for configuration: Configuration) -> Color {
        switch kind {
        case .primary:
            configuration.isPressed ? Color.accentColor.opacity(0.82) : Color.accentColor
        case .secondary:
            configuration.isPressed
                ? Color(nsColor: .controlAccentColor).opacity(0.18)
                : Color(nsColor: .controlBackgroundColor)
        }
    }
}

private struct BehaviorSummary: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Behavior")
                    .font(.headline)
                Spacer()
                Button {
                    model.resetSelectedControl()
                } label: {
                    Label("Reset Control", systemImage: "arrow.counterclockwise")
                }
            }

            Label("Runs once when the control is pressed", systemImage: "hand.tap")
                .fontWeight(.medium)
            Text("The verified HID configuration writes the selected action directly. This device does not expose repeat or long-press modes.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct KnobActionSelector: View {
    @EnvironmentObject private var model: AppModel
    let number: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Knob Action")
                .font(.headline)
            Picker("Knob Action", selection: selection) {
                Label("Turn Left", systemImage: "rotate.left")
                    .tag(PadControlID.knobLeft(number))
                Label("Press", systemImage: "button.programmable")
                    .tag(PadControlID.knobPush(number))
                Label("Turn Right", systemImage: "rotate.right")
                    .tag(PadControlID.knobRight(number))
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityIdentifier("knob-action-picker")
        }
    }

    private var selection: Binding<PadControlID> {
        Binding(
            get: { model.selectedControl },
            set: { model.selectedControl = $0 }
        )
    }
}

private struct ActionTypeButton: View {
    let kind: ActionKind
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: kind.symbol)
                    .font(.title3)
                Text(kind.rawValue)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, minHeight: 62)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? Color.accentColor : .primary)
        .background(selected ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? Color.accentColor.opacity(0.45) : .clear))
    }
}

private struct MacroSequenceEditor: View {
    @EnvironmentObject private var model: AppModel
    private let rowHeight: CGFloat = 58
    private let maximumVisibleRows: CGFloat = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Macro Sequence")
                    .font(.headline)
                Spacer()
                Button {
                    model.addKeystroke()
                } label: {
                    Label("Add Keystroke", systemImage: "plus")
                }
                .disabled(model.selectedBinding.sequence.count >= model.profile.maxSequenceLength)
            }

            Group {
                if model.selectedBinding.sequence.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(model.selectedBinding.sequence.enumerated()), id: \.element.id) { index, stroke in
                                KeystrokeRow(index: index, stroke: stroke)
                                if index + 1 < model.selectedBinding.sequence.count { Divider() }
                            }
                        }
                    }
                    .frame(height: sequenceListHeight)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.separator.opacity(0.45)))

            HStack {
                Stepper(value: delayBinding, in: 0...5_000, step: 10) {
                    HStack {
                        Text("Inter-key delay")
                        Text("\(model.selectedBinding.interKeyDelayMilliseconds) ms")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!model.profile.supportsDelay)
                Spacer()
                Text("\(model.selectedBinding.sequence.count) of \(model.profile.maxSequenceLength) keystrokes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "keyboard.badge.ellipsis")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("No keystrokes")
                .fontWeight(.medium)
            Text("Add a keystroke to make this control active.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
    }

    private var sequenceListHeight: CGFloat {
        min(CGFloat(model.selectedBinding.sequence.count) * rowHeight, maximumVisibleRows * rowHeight)
    }

    private var delayBinding: Binding<UInt16> {
        Binding(get: { model.selectedBinding.interKeyDelayMilliseconds }, set: { value in
            model.updateSelectedBinding { $0.interKeyDelayMilliseconds = value }
        })
    }
}

private struct KeystrokeRow: View {
    @EnvironmentObject private var model: AppModel
    let index: Int
    let stroke: Keystroke

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
            Text("\(index + 1)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 18)
            KeystrokeRecorderField(keystroke: stroke) { recordedStroke in
                updateStroke { $0 = recordedStroke }
            }
            .frame(width: 190, height: 32)

            Menu {
                Picker("Key", selection: keyBinding) {
                    ForEach(HIDKey.allCases) { key in Text(key.displayName).tag(key) }
                }
                Divider()
                Toggle("Command", isOn: modifierBinding(.leftCommand))
                Toggle("Shift", isOn: modifierBinding(.leftShift))
                Toggle("Option", isOn: modifierBinding(.leftOption))
                Toggle("Control", isOn: modifierBinding(.leftControl))
            } label: {
                HStack(spacing: 4) {
                    Text("Choose...")
                    Image(systemName: "chevron.down")
                }
            }
            .menuStyle(.borderlessButton)
            .help("Choose a key and modifiers manually")
            Spacer()
            Button { model.moveKeystrokeUp(id: stroke.id) } label: { Image(systemName: "chevron.up") }
                .disabled(index == 0)
                .help("Move earlier")
            Button { model.moveKeystrokeDown(id: stroke.id) } label: { Image(systemName: "chevron.down") }
                .disabled(index + 1 == model.selectedBinding.sequence.count)
                .help("Move later")
            Button(role: .destructive) { model.removeKeystroke(id: stroke.id) } label: { Image(systemName: "trash") }
                .help("Remove keystroke")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 14)
        .frame(minHeight: 58)
    }

    private var keyBinding: Binding<HIDKey> {
        Binding(get: { stroke.key }, set: { value in updateStroke { $0.key = value } })
    }

    private func modifierBinding(_ modifier: HIDModifier) -> Binding<Bool> {
        Binding(get: { stroke.modifiers.contains(modifier) }, set: { enabled in
            updateStroke { value in
                if enabled { value.modifiers.insert(modifier) } else { value.modifiers.remove(modifier) }
            }
        })
    }

    private func updateStroke(_ mutate: (inout Keystroke) -> Void) {
        model.updateSelectedBinding { binding in
            guard let index = binding.sequence.firstIndex(where: { $0.id == stroke.id }) else { return }
            mutate(&binding.sequence[index])
        }
    }
}
