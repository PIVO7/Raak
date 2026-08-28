import XCTest
import SwiftUI
@testable import Raak

/// Geen assert-tests maar een rooktest die de belangrijkste views naar PNG
/// rendert, zodat een build zonder simulator-interactie toch visueel te
/// controleren valt. De bestanden landen in de map uit RENDER_OUTPUT_DIR;
/// zonder die variabele slaat de test over.
@MainActor
final class RenderSmokeTests: XCTestCase {
    private var outputDirectory: URL? {
        ProcessInfo.processInfo.environment["RENDER_OUTPUT_DIR"].map {
            URL(fileURLWithPath: $0, isDirectory: true)
        }
    }

    func testRenderKeyScreens() throws {
        guard let outputDirectory else {
            throw XCTSkip("RENDER_OUTPUT_DIR niet gezet; rooktest alleen op verzoek.")
        }

        let engine = GameEngine(
            mode: .versusFriends,
            profiles: [
                PlayerProfile(name: "Lene"),
                PlayerProfile(name: "Ellis", avatarColorIndex: 1)
            ],
            boardSize: .medium,
            seed: 7
        )
        engine.confirmFleet()
        engine.confirmFleet()
        // Een treffer, een gezonken boot en een misser: alle staten in beeld.
        let sloep = engine.boards[1].ships.first { $0.kind == .sloep }!
        for cell in sloep.cells {
            engine.fire(at: cell)
        }
        let stoomboot = engine.boards[1].ships.first { $0.kind == .stoomboot }!
        engine.fire(at: stoomboot.cells[0])

        try render(
            BoardGridView(
                board: engine.boards[1],
                showsShips: false,
                isEnabled: true,
                lastShot: stoomboot.cells[0],
                onFire: { _ in }
            )
            .padding(16)
            .frame(width: 390, height: 460)
            .background(AppTheme.cream),
            to: outputDirectory.appending(path: "bord.png")
        )

        try render(
            PaywallView(entitlements: EntitlementStore(previewUnlocked: false))
                .frame(width: 390, height: 760),
            to: outputDirectory.appending(path: "paywall.png")
        )

        try render(
            GameResultOverlay(
                players: engine.players,
                winnerProfileIDs: [engine.players[0].profileID],
                message: "Lene wint — de hele vloot is gezonken!",
                hitCounts: [12, 7],
                shipsSunk: [4, 2],
                isNewRecord: true,
                animatesIn: false,
                onRematch: {},
                onClose: {}
            )
            .frame(width: 390, height: 760)
            .background(AppTheme.cream),
            to: outputDirectory.appending(path: "result.png")
        )
    }

    private func render(_ view: some View, to url: URL) throws {
        let renderer = ImageRenderer(content: view.environment(\.metrics, .phone))
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage, "Renderen mislukt voor \(url.lastPathComponent)")
        try XCTUnwrap(image.pngData()).write(to: url)
    }
}
