import SwiftUI

@main
struct MacroPadStudioApp: App {
  @NSApplicationDelegateAdaptor(AppLifecycleController.self) private var lifecycleController
  @StateObject private var model = AppModel()

  var body: some Scene {
    WindowGroup(id: "main") {
      ContentView()
        .environmentObject(model)
        .frame(minWidth: 1_120, minHeight: 720)
    }
    .windowStyle(.hiddenTitleBar)
    .defaultSize(width: 1_360, height: 860)
    .commands {
      CommandMenu("Device") {
        Button("Load Configuration from Device") {
          model.readFromDevice()
        }
        .keyboardShortcut("r", modifiers: [.command, .shift])
        .disabled(!model.canReadFromDevice)

        Button("Store Pending Changes to Device") {
          model.requestApply()
        }
        .keyboardShortcut("s", modifiers: [.command, .shift])
        .disabled(!model.canApply)
      }
    }

    MenuBarExtra("MacroPad Studio", systemImage: "keyboard") {
      BackgroundMenuView()
    }

    Settings {
      SettingsView()
        .environmentObject(model)
    }
  }
}
