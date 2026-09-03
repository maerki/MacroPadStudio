import SwiftUI

struct ContentView: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    VStack(spacing: 0) {
      HSplitView {
        DeviceCanvasView()
          .frame(minWidth: 330, idealWidth: 390, maxWidth: 460)
        KeyEditorView()
          .frame(minWidth: 500, idealWidth: 650)
      }
      StatusBarView()
    }
    .background(Color(nsColor: .windowBackgroundColor))
    .toolbar {
      ToolbarItem(placement: .navigation) {
        DeviceMenu()
      }
    }
    .sheet(isPresented: $model.showingApplyReview) {
      ApplyReviewView()
        .environmentObject(model)
    }
    .alert("Read configuration from device?", isPresented: $model.showingReadReview) {
      Button("Cancel", role: .cancel) {}
      Button("Read Configuration") { model.confirmReadFromDevice() }
    } message: {
      Text(
        "This replaces all local key and knob assignments with the values stored on the keypad. Layer names and lighting remain unchanged because the device does not return lighting data."
      )
    }
    .animation(.snappy, value: model.notice)
  }

}

private struct DeviceMenu: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    Menu {
      Section("Current") {
        Label(
          model.connectionTitle,
          systemImage: model.isHardwareConnected ? "keyboard.badge.ellipsis" : "play.rectangle")
        Text(model.connectionDetail)
        if let batteryLevel = model.batteryLevel {
          Label("Battery \(batteryLevel)%", systemImage: batterySymbol(for: batteryLevel))
        }
      }
      Divider()
      Text("Supported hardware is detected automatically.")
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "keyboard")
        VStack(alignment: .leading, spacing: 1) {
          Text(model.connectionTitle)
            .fontWeight(.medium)
          Text(model.isHardwareConnected ? "Connected" : "Demo Mode")
            .font(.caption2)
            .foregroundStyle(model.canWriteToDevice ? .green : .secondary)
        }
      }
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
  }

  private func batterySymbol(for batteryLevel: Int) -> String {
    switch batteryLevel {
    case 76...100: "battery.100percent"
    case 51...75: "battery.75percent"
    case 26...50: "battery.50percent"
    case 1...25: "battery.25percent"
    default: "battery.0percent"
    }
  }
}

private struct StatusBarView: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    HStack(spacing: 10) {
      Circle()
        .fill(model.canWriteToDevice ? Color.green : Color.orange)
        .frame(width: 9, height: 9)
      Text(statusTitle)
        .foregroundStyle(model.canWriteToDevice ? .green : .secondary)
      Text("•")
        .foregroundStyle(.tertiary)
      Text(model.connectionDetail)
        .foregroundStyle(.secondary)
      Spacer()
      if model.isWritingConfiguration {
        Label("Syncing to device...", systemImage: "arrow.triangle.2.circlepath")
          .foregroundStyle(.blue)
      } else if model.isReadingConfiguration {
        Label("Loading from device...", systemImage: "arrow.down.to.line")
          .foregroundStyle(.blue)
      } else if let notice = model.notice {
        Label(notice.message, systemImage: noticeSymbol(for: notice.kind))
          .foregroundStyle(noticeColor(for: notice.kind))
          .lineLimit(1)
      } else if model.changeCount > 0 {
        Label(changeLabel, systemImage: "circle.fill")
          .symbolRenderingMode(.monochrome)
          .foregroundStyle(.orange)
      } else {
        Label("Up to date", systemImage: "checkmark.circle.fill")
          .foregroundStyle(.green)
      }
    }
    .font(.caption)
    .padding(.horizontal, 18)
    .frame(height: 38)
    .background(.bar)
    .overlay(alignment: .top) { Divider() }
  }

  private var statusTitle: String {
    if model.isWritingConfiguration { return "Syncing configuration" }
    if model.isReadingConfiguration { return "Loading configuration" }
    if model.changeCount > 0 { return "Pending changes" }
    if model.canWriteToDevice { return "Configuration ready" }
    if model.isHardwareConnected { return "Bluetooth device detected" }
    return "Demo mode"
  }

  private var changeLabel: String {
    let base = "\(model.changeCount) unsaved \(model.changeCount == 1 ? "change" : "changes")"
    return model.isHardwareConnected && !model.canWriteToDevice ? "\(base) • Cannot apply" : base
  }

  private func noticeColor(for kind: AppModel.Notice.Kind) -> Color {
    switch kind {
    case .success: .green
    case .warning: .orange
    case .error: .red
    }
  }

  private func noticeSymbol(for kind: AppModel.Notice.Kind) -> String {
    switch kind {
    case .success: "checkmark.circle.fill"
    case .warning: "exclamationmark.triangle.fill"
    case .error: "xmark.octagon.fill"
    }
  }
}
