import AppKit

final class AppLifecycleController: NSObject, NSApplicationDelegate {
  static let keepRunningAfterWindowCloseKey = "keepRunningAfterWindowClose"

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    Self.shouldTerminateAfterLastWindowClosed(keepRunning: keepRunningAfterWindowClose)
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    if !flag {
      sender.activate(ignoringOtherApps: true)
    }
    return true
  }

  static func shouldTerminateAfterLastWindowClosed(keepRunning: Bool) -> Bool {
    !keepRunning
  }

  private var keepRunningAfterWindowClose: Bool {
    guard UserDefaults.standard.object(forKey: Self.keepRunningAfterWindowCloseKey) != nil else {
      return true
    }
    return UserDefaults.standard.bool(forKey: Self.keepRunningAfterWindowCloseKey)
  }
}
