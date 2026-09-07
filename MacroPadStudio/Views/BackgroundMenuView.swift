import AppKit
import SwiftUI

struct BackgroundMenuView: View {
  @Environment(\.openWindow) private var openWindow
  @AppStorage(AppLifecycleController.keepRunningAfterWindowCloseKey) private
    var keepRunningAfterWindowClose = true

  var body: some View {
    Button("Show MacroPad Studio") {
      openWindow(id: "main")
    }
    Toggle("Keep running after closing window", isOn: $keepRunningAfterWindowClose)
    Divider()
    Button("Quit MacroPad Studio") {
      NSApplication.shared.terminate(nil)
    }
  }
}
