import Foundation

struct ConfigurationStore: Sendable {
    private let fileURL: URL

    init(baseURL: URL? = nil) {
        let root = baseURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        fileURL = root.appending(path: "MacroPadStudio", directoryHint: .isDirectory)
            .appending(path: "configuration.json", directoryHint: .notDirectory)
    }

    func load(for profile: DeviceProfile) throws -> PadConfiguration {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .starter(for: profile)
        }
        let data = try Data(contentsOf: fileURL)
        var decoded = try JSONDecoder().decode(PadConfiguration.self, from: data)
        guard decoded.profileID == profile.id else { return .starter(for: profile) }
        if !profile.supportsDelay {
            for layerIndex in decoded.layers.indices {
                for control in decoded.layers[layerIndex].bindings.keys {
                    decoded.layers[layerIndex].bindings[control]?.interKeyDelayMilliseconds = 0
                }
            }
        }
        return decoded
    }

    func save(_ configuration: PadConfiguration) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(configuration).write(to: fileURL, options: .atomic)
    }
}
