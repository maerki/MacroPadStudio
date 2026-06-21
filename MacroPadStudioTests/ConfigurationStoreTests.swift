import Foundation
import XCTest
@testable import MacroPadStudio

final class ConfigurationStoreTests: XCTestCase {
    func testRoundTripPersistsConfiguration() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ConfigurationStore(baseURL: root)
        var configuration = PadConfiguration.starter(for: .demo)
        configuration.layers[0].name = "Editing"
        configuration.layers[0].lighting.color = .purple

        try store.save(configuration)
        let loaded = try store.load(for: .demo)

        XCTAssertEqual(loaded, configuration)
    }

    func testMissingFileProducesStarterConfiguration() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let store = ConfigurationStore(baseURL: root)

        let loaded = try store.load(for: .demo)

        XCTAssertEqual(loaded.profileID, DeviceProfile.demo.id)
        XCTAssertEqual(loaded.layers.count, DeviceProfile.demo.layerCount)
    }
}
