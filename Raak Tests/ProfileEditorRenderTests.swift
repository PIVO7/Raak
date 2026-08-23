import XCTest
import SwiftUI
@testable import Raak

/// Rendert de profielschermen naar PNG, zodat de geporte editor zonder
/// simulator-interactie visueel te controleren valt. Slaat over zonder
/// RENDER_OUTPUT_DIR.
@MainActor
final class ProfileEditorRenderTests: XCTestCase {
    private var outputDirectory: URL? {
        ProcessInfo.processInfo.environment["RENDER_OUTPUT_DIR"].map {
            URL(fileURLWithPath: $0, isDirectory: true)
        }
    }

    func testRenderProfileScreens() throws {
        guard let outputDirectory else {
            throw XCTSkip("RENDER_OUTPUT_DIR niet gezet; rooktest alleen op verzoek.")
        }

        let store = ProfileStore(fileURL: URL.temporaryDirectory.appending(path: "render-\(UUID()).json"))
        store.addProfile(name: "Lene", colorIndex: 0, symbol: "heart.fill")
        store.addProfile(name: "Ellis", colorIndex: 1, symbol: "star.fill")

        // ImageRenderer slaat ScrollView-inhoud over; het formulier zelf
        // rendert wel. Nieuw profiel: leeg veld, voorgestelde kleur.
        try render(
            ProfileEditorFormView(name: .constant(""), colorIndex: .constant(2), symbol: .constant(nil), staticNameForRender: true)
                .padding(20)
                .background(AppTheme.cream),
            to: outputDirectory.appending(path: "editor-nieuw.png")
        )

        // Bestaand profiel: naam, kleur en symbool vooraf ingevuld.
        try render(
            ProfileEditorFormView(name: .constant("Lene"), colorIndex: .constant(0), symbol: .constant("heart.fill"), staticNameForRender: true)
                .padding(20)
                .background(AppTheme.cream),
            to: outputDirectory.appending(path: "editor-bewerken.png")
        )

        // De profielrijen die de editor openen.
        try render(
            VStack(spacing: 14) {
                ForEach(store.humanProfiles) { profile in
                    ProfileRowView(
                        profile: profile,
                        onEdit: { _, _, _ in },
                        onDelete: {}
                    )
                }
            }
            .padding(20)
            .background(AppTheme.cream),
            to: outputDirectory.appending(path: "profielen.png")
        )
    }

    private func render(_ view: some View, to url: URL) throws {
        let renderer = ImageRenderer(
            content: view.environment(\.metrics, .phone).frame(width: 393, height: 760)
        )
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage, "Renderen mislukt voor \(url.lastPathComponent)")
        try XCTUnwrap(image.pngData()).write(to: url)
    }
}
