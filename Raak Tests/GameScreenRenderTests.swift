import XCTest
import SwiftUI
@testable import Raak

/// Rendert het volledige spelscherm naar PNG, zodat een indeling zonder
/// simulator te beoordelen valt. Slaat over zonder RENDER_OUTPUT_DIR.
@MainActor
final class GameScreenRenderTests: XCTestCase {
    private var outputDirectory: URL? {
        ProcessInfo.processInfo.environment["RENDER_OUTPUT_DIR"].map {
            URL(fileURLWithPath: $0, isDirectory: true)
        }
    }

    func testRenderGameScreen() throws {
        guard let outputDirectory else {
            throw XCTSkip("RENDER_OUTPUT_DIR niet gezet; rooktest alleen op verzoek.")
        }

        let engine = GameEngine(
            mode: .versusComputer,
            profiles: [
                PlayerProfile(name: "Lene", avatarColorIndex: 4, avatarSymbol: "heart.fill"),
                .computer(level: .medium)
            ],
            boardSize: .medium,
            seed: 7
        )
        engine.confirmFleet()
        // Een gezonken boot, een treffer en een misser: alle staten in beeld.
        let sloep = engine.boards[1].ships.first { $0.kind == .sloep }!
        for cell in sloep.cells {
            engine.fire(at: cell)
        }
        let stoomboot = engine.boards[1].ships.first { $0.kind == .stoomboot }!
        engine.fire(at: stoomboot.cells[0])

        // Twee maten: iPhone en iPad portret, zodat een indeling op beide
        // te beoordelen valt.
        let variants: [(suffix: String, width: CGFloat, height: CGFloat, metrics: AppMetrics)] = [
            ("", 393, 852, .phone),
            ("-ipad", 834, 1194, .pad)
        ]
        for variant in variants {
            let view = GameView(engine: engine, onRematch: {}, onClose: {})
                .environment(ProfileStore(fileURL: URL.temporaryDirectory.appending(path: "render-\(UUID()).json")))
                .environment(GameStore(fileURL: URL.temporaryDirectory.appending(path: "render-\(UUID()).json")))
                .environment(\.metrics, variant.metrics)
                .frame(width: variant.width, height: variant.height)

            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.uiImage)
            try XCTUnwrap(image.pngData())
                .write(to: outputDirectory.appending(path: "spelscherm\(variant.suffix).png"))
        }
    }
}
