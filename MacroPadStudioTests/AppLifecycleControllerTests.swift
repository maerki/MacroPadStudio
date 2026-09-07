import XCTest

@testable import MacroPadStudio

final class AppLifecycleControllerTests: XCTestCase {
  func testClosingLastWindowKeepsAppRunningByDefault() {
    XCTAssertFalse(AppLifecycleController.shouldTerminateAfterLastWindowClosed(keepRunning: true))
  }

  func testClosingLastWindowTerminatesWhenConfigured() {
    XCTAssertTrue(AppLifecycleController.shouldTerminateAfterLastWindowClosed(keepRunning: false))
  }
}
