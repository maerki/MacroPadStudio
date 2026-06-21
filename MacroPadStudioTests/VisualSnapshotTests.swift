import AppKit
import SwiftUI
import XCTest
@testable import MacroPadStudio

@MainActor
final class VisualSnapshotTests: XCTestCase {
    func testFocusedEditorSnapshot() throws {
        let model = AppModel(
            hidService: HIDDeviceService(discoveryEnabled: false),
            store: ConfigurationStore(baseURL: FileManager.default.temporaryDirectory)
        )
        let rootView = HStack(spacing: 1) {
            DeviceCanvasView()
                .frame(width: 390)
            KeyEditorView()
                .frame(width: 969)
        }
            .environmentObject(model)
            .frame(width: 1_360, height: 820)

        let renderer = ImageRenderer(content: rootView)
        renderer.proposedSize = ProposedViewSize(width: 1_360, height: 820)
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.nsImage)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation)))

        let properties: [NSBitmapImageRep.PropertyKey: Any] = [.compressionFactor: 1.0]
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: properties))
        let output = URL(fileURLWithPath: "/tmp/macropadstudio-visual.png")
        try data.write(to: output, options: .atomic)

        XCTAssertGreaterThan(bitmap.pixelsWide, 1_000)
        XCTAssertGreaterThan(bitmap.pixelsHigh, 650)
        let samples = stride(from: 0, to: bitmap.pixelsWide, by: 80).flatMap { x in
            stride(from: 0, to: bitmap.pixelsHigh, by: 80).compactMap { y in
                bitmap.colorAt(x: x, y: y)?.brightnessComponent
            }
        }
        XCTAssertGreaterThan(samples.filter { $0 > 0.08 }.count, 10)
    }
}
