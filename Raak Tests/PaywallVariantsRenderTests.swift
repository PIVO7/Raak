import XCTest
import SwiftUI
@testable import Raak

/// Ontwerpverkenning voor de paywall: drie aantrekkelijkere varianten,
/// gerenderd naar PNG zodat er buiten de simulator te kiezen valt. Na de
/// keuze mag dit bestand weg. Slaat over zonder RENDER_OUTPUT_DIR.
@MainActor
final class PaywallVariantsRenderTests: XCTestCase {
    private var outputDirectory: URL? {
        ProcessInfo.processInfo.environment["RENDER_OUTPUT_DIR"].map {
            URL(fileURLWithPath: $0, isDirectory: true)
        }
    }

    func testRenderPaywallVariants() throws {
        guard let outputDirectory else {
            throw XCTSkip("RENDER_OUTPUT_DIR niet gezet; rooktest alleen op verzoek.")
        }
        try render(PaywallVariantTiles(), to: outputDirectory.appending(path: "paywall-1-speelgoedtegels.png"))
        try render(PaywallVariantBanner(), to: outputDirectory.appending(path: "paywall-2-feestbanner.png"))
        try render(PaywallVariantMedallion(), to: outputDirectory.appending(path: "paywall-3-medaillon.png"))
    }

    private func render(_ view: some View, to url: URL) throws {
        let renderer = ImageRenderer(
            content: view.environment(\.metrics, .phone).frame(width: 393, height: 780)
        )
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage, "Renderen mislukt voor \(url.lastPathComponent)")
        try XCTUnwrap(image.pngData()).write(to: url)
    }
}

// MARK: - Gedeelde stukjes

private struct PaywallCloseButton: View {
    @Environment(\.metrics) private var m

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Label("Sluiten", systemImage: "xmark")
                    .labelStyle(.iconOnly)
                    .font(.system(size: m.captionSize + 2, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: m.tapTarget, height: m.tapTarget)
                    .toyBlock(fill: AppTheme.card, radius: m.cellCorner, depth: 3, border: m.thinBorder)
            }
            Spacer()
        }
        .padding(m.gutter * 1.4)
    }
}

private struct PaywallBuyButton: View {
    var fill: Color
    @Environment(\.metrics) private var m

    var body: some View {
        VStack(spacing: m.gutter * 0.7) {
            Text("Ontgrendel voor € 4,99")
                .font(AppTheme.rounded(m.buttonTextSize * 0.8))
                .foregroundStyle(AppTheme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: m.buttonHeight * 0.85)
                .toyBlock(fill: fill, radius: m.cardCorner * 0.9, depth: m.depth, border: m.border)

            Text("Eerder gekocht? Zet terug")
                .font(AppTheme.rounded(m.captionSize, .bold))
                .foregroundStyle(AppTheme.soft)
        }
    }
}

// MARK: - Variant 1: speelgoedtegels, familie van het startscherm

private struct PaywallVariantTiles: View {
    @Environment(\.metrics) private var m

    var body: some View {
        ZStack {
            ThemedBackground()

            VStack(spacing: m.gutter) {
                HStack(spacing: -m.discSize * 0.15) {
                    TileBadge(symbol: "sailboat.fill", colorIndex: 1, size: m.discSize * 0.95)
                        .rotationEffect(.degrees(-8))
                        .zIndex(1)
                    TileBadge(symbol: "figure.2.and.child.holdinghands", colorIndex: 0, size: m.discSize * 1.1)
                        .zIndex(2)
                    TileBadge(symbol: "burst.fill", colorIndex: 2, size: m.discSize * 0.95)
                        .rotationEffect(.degrees(8))
                        .offset(y: m.discSize * 0.1)
                }
                .padding(.top, m.gutter * 2.5)

                Text("Gezinsversie")
                    .font(AppTheme.rounded(m.titleSize * 0.7))
                    .foregroundStyle(AppTheme.headline)

                Text("Eén keer kopen, voor het hele gezin — ook via Delen met gezin.")
                    .font(AppTheme.rounded(m.captionSize + 2, .bold))
                    .foregroundStyle(AppTheme.soft)
                    .multilineTextAlignment(.center)

                VStack(spacing: m.gutter * 0.7) {
                    row("graduationcap.fill", tint: AppTheme.tintSky, symbolColor: 1,
                        "Alle drie de tegenstanders: Dommel, Robbie en Professor Punt")
                    row("paintpalette.fill", tint: AppTheme.tintCoral, symbolColor: 0,
                        "Alle kleurenthema's: Snoep, Oceaan en Nacht")
                    row("trophy.fill", tint: AppTheme.tintAmber, symbolColor: 2,
                        "Statistieken per speler, met trofeeën en gezinsrecords")
                }

                Spacer(minLength: m.gutter)

                PaywallBuyButton(fill: AppTheme.mint)
                    .padding(.bottom, m.gutter * 1.5)
            }
            .padding(.horizontal, m.gutter * 1.4)

            PaywallCloseButton()
        }
    }

    private func row(_ icon: String, tint: Color, symbolColor: Int, _ text: String) -> some View {
        HStack(spacing: m.gutter * 0.8) {
            TileBadge(symbol: icon, colorIndex: symbolColor, size: m.avatarSize * 0.6)
                .frame(width: m.avatarSize * 0.9, height: m.avatarSize * 0.9)
                .toyBlock(fill: tint, radius: m.cellCorner + 2, depth: 0, border: m.thinBorder + 0.5)

            Text(text)
                .font(AppTheme.rounded(m.captionSize + 2, .bold))
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(m.gutter * 0.8)
        .toyBlock(fill: AppTheme.card, radius: m.cardCorner * 0.8, depth: 3, border: m.thinBorder + 0.5)
    }
}

// MARK: - Variant 2: feestbanner met getinte featurekaarten

private struct PaywallVariantBanner: View {
    @Environment(\.metrics) private var m

    var body: some View {
        ZStack {
            ThemedBackground()

            VStack(spacing: m.gutter) {
                VStack(spacing: 6) {
                    Image(systemName: "figure.2.and.child.holdinghands")
                        .font(.system(size: m.titleSize * 0.9, weight: .black))
                        .foregroundStyle(.white)
                    Text("Gezinsversie")
                        .font(AppTheme.rounded(m.titleSize * 0.62))
                        .foregroundStyle(.white)
                    Text("Eén keer kopen — voor iedereen, via Delen met gezin")
                        .font(AppTheme.rounded(m.captionSize, .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, m.gutter * 1.2)
                .padding(.horizontal, m.gutter)
                .toyBlock(fill: AppTheme.coral, radius: m.cardCorner, depth: m.depth + 1, border: m.border)
                .overlay(alignment: .topLeading) {
                    Image(systemName: "sparkles")
                        .font(.system(size: m.bodySize, weight: .black))
                        .foregroundStyle(AppTheme.amber)
                        .offset(x: m.gutter * 0.8, y: m.gutter * 0.6)
                }
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "sparkles")
                        .font(.system(size: m.bodySize, weight: .black))
                        .foregroundStyle(AppTheme.amber)
                        .offset(x: -m.gutter * 0.8, y: -m.gutter * 0.5)
                }
                .padding(.top, m.tapTarget + m.gutter * 1.6)

                card(tint: AppTheme.tintSky, icon: "graduationcap.fill",
                     title: "Drie tegenstanders",
                     text: "Dommel, Robbie en Professor Punt")
                card(tint: AppTheme.tintCoral, icon: "paintpalette.fill",
                     title: "Alle kleurenthema's",
                     text: "Snoep, Oceaan en Nacht")
                card(tint: AppTheme.tintAmber, icon: "trophy.fill",
                     title: "Statistieken en trofeeën",
                     text: "Per speler, met winreeks en gezinsrecords")

                Spacer(minLength: m.gutter)

                PaywallBuyButton(fill: AppTheme.amber)
                    .padding(.bottom, m.gutter * 1.5)
            }
            .padding(.horizontal, m.gutter * 1.4)

            PaywallCloseButton()
        }
    }

    private func card(tint: Color, icon: String, title: String, text: String) -> some View {
        HStack(spacing: m.gutter * 0.8) {
            Image(systemName: icon)
                .font(.system(size: m.bodySize + 2, weight: .black))
                .foregroundStyle(AppTheme.ink)
                .frame(width: m.avatarSize * 0.8, height: m.avatarSize * 0.8)
                .background(Circle().fill(.white.opacity(0.7)))
                .overlay { Circle().strokeBorder(AppTheme.ink, lineWidth: m.thinBorder) }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.rounded(m.bodySize))
                    .foregroundStyle(AppTheme.ink)
                Text(text)
                    .font(AppTheme.rounded(m.captionSize, .bold))
                    .foregroundStyle(AppTheme.cardSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(m.gutter * 0.8)
        .toyBlock(fill: tint, radius: m.cardCorner * 0.8, depth: 3, border: m.thinBorder + 0.5)
    }
}

// MARK: - Variant 3: medaillon met vinkjeslijst en grote prijs

private struct PaywallVariantMedallion: View {
    @Environment(\.metrics) private var m

    var body: some View {
        ZStack {
            ThemedBackground()

            VStack(spacing: m.gutter) {
                Image(systemName: "figure.2.and.child.holdinghands")
                    .font(.system(size: m.avatarSize, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: m.avatarSize * 1.9, height: m.avatarSize * 1.9)
                    .toyBlock(
                        fill: AppTheme.coral,
                        radius: m.avatarSize * 0.95,
                        depth: m.depth,
                        border: m.border
                    )
                    .overlay(alignment: .top) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: m.avatarSize * 0.5, weight: .black))
                            .foregroundStyle(AppTheme.amber)
                            .rotationEffect(.degrees(14))
                            .offset(x: m.avatarSize * 0.62, y: -m.avatarSize * 0.42)
                    }
                    .padding(.top, m.tapTarget + m.gutter * 1.6)

                Text("Gezinsversie")
                    .font(AppTheme.rounded(m.titleSize * 0.7))
                    .foregroundStyle(AppTheme.headline)

                VStack(alignment: .leading, spacing: m.gutter * 0.8) {
                    check("Alle drie de tegenstanders: Dommel, Robbie en Professor Punt")
                    check("Alle kleurenthema's: Snoep, Oceaan en Nacht")
                    check("Statistieken, trofeeën en gezinsrecords")
                    check("Eén aankoop, ook via Delen met gezin")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(m.gutter)
                .toyBlock(fill: AppTheme.card, radius: m.cardCorner * 0.9, depth: m.depth, border: m.border)

                Spacer(minLength: m.gutter * 0.5)

                VStack(spacing: 2) {
                    Text("€ 4,99")
                        .font(AppTheme.rounded(m.titleSize * 0.75))
                        .foregroundStyle(AppTheme.headline)
                    Text("één keer, voor het hele gezin")
                        .font(AppTheme.rounded(m.captionSize, .bold))
                        .foregroundStyle(AppTheme.soft)
                }

                VStack(spacing: m.gutter * 0.7) {
                    Text("Ontgrendelen")
                        .font(AppTheme.rounded(m.buttonTextSize * 0.8))
                        .foregroundStyle(AppTheme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: m.buttonHeight * 0.85)
                        .toyBlock(fill: AppTheme.mint, radius: m.cardCorner * 0.9, depth: m.depth, border: m.border)

                    Text("Eerder gekocht? Zet terug")
                        .font(AppTheme.rounded(m.captionSize, .bold))
                        .foregroundStyle(AppTheme.soft)
                }
                .padding(.bottom, m.gutter * 1.5)
            }
            .padding(.horizontal, m.gutter * 1.4)

            PaywallCloseButton()
        }
    }

    private func check(_ text: String) -> some View {
        HStack(alignment: .top, spacing: m.gutter * 0.6) {
            Image(systemName: "checkmark")
                .font(.system(size: m.captionSize, weight: .black))
                .foregroundStyle(AppTheme.ink)
                .frame(width: m.captionSize * 1.8, height: m.captionSize * 1.8)
                .background(Circle().fill(AppTheme.mint))
                .overlay { Circle().strokeBorder(AppTheme.ink, lineWidth: m.thinBorder) }

            Text(text)
                .font(AppTheme.rounded(m.captionSize + 2, .bold))
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
