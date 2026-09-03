import SwiftUI

/// De spelregels op kindhoogte: hoe een beurt werkt en hoe je wint.
struct RulesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.metrics) private var m

    var body: some View {
        ZStack {
            ThemedBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: m.gutter * 1.4) {
                    HStack {
                        Text("Hoe werkt het?")
                            .font(AppTheme.rounded(m.titleSize * 0.62))
                            .foregroundStyle(AppTheme.headline)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)

                        Spacer()

                        Button(action: { dismiss() }) {
                            Label("Sluiten", systemImage: "xmark")
                                .labelStyle(.iconOnly)
                                .font(.system(size: m.captionSize + 2, weight: .black))
                                .foregroundStyle(AppTheme.ink)
                                .frame(width: m.tapTarget, height: m.tapTarget)
                        }
                        .buttonStyle(ToyButtonStyle(fill: AppTheme.card, radius: m.cellCorner, depth: m.shallowDepth, border: m.thinBorder))
                    }

                    section("ZO SPEEL JE") {
                        card {
                            bullet("dice.fill", String(localized: "Schud je vloot en leg hem geheim klaar — de ander mag niet kijken!"))
                            bullet("hand.tap.fill", String(localized: "Tik een vakje op de zee van de ander om te schieten."))
                            bullet("arrow.clockwise", String(localized: "Raak? Dan mag je meteen nog een keer. Mis? Dan mag de ander."))
                        }
                    }

                    section("ZO WIN JE") {
                        card {
                            bullet("water.waves", String(localized: "Raak je alle vakjes van een boot, dan zinkt hij."))
                            bullet("crown.fill", String(localized: "Wie als eerste de hele vloot van de ander laat zinken, wint!"))
                        }
                    }

                    section("SALVO") {
                        card {
                            bullet("burst.fill", String(localized: "In deze spelvorm schiet je per beurt zoveel keer als je nog boten hebt: vier boten, vier schoten."))
                            bullet("arrow.uturn.right", String(localized: "Raak of mis maakt niet uit — je schiet je hele salvo af en dan is de ander."))
                            bullet("exclamationmark.triangle.fill", String(localized: "Zinkt er een boot van jou, dan wordt jouw salvo korter. Pas dus op je vloot!"))
                            bullet("figure.2.and.child.holdinghands", String(localized: "Hoort bij de Gezinsversie."))
                        }
                    }

                    section("SLIMME TRUCJES") {
                        card {
                            bullet("brain.head.profile", String(localized: "Kijk goed naar je schoten: een bubbel is water, een knal is boot."))
                            bullet("sparkle.magnifyingglass", String(localized: "Raak geschoten? Probeer de vakjes ernaast — daar ligt de rest van de boot."))
                            bullet("checkerboard.rectangle", String(localized: "Verspreid je schoten over de hele zee, zo vind je elke boot."))
                        }
                    }
                }
                .padding(.horizontal, m.gutter * 1.3)
                .padding(.top, m.gutter)
                .padding(.bottom, m.gutter * 2)
                .frame(maxWidth: m.overlayMaxWidth)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func section(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: m.gutter * 0.6) {
            Text(title)
                .font(AppTheme.rounded(m.captionSize * 0.9))
                .kerning(1.4)
                .foregroundStyle(AppTheme.faint)
            content()
        }
    }

    private func card(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: m.gutter * 0.9) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(m.gutter)
        .toyBlock(fill: AppTheme.card, radius: m.cardCorner, depth: m.depth, border: m.border)
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: m.gutter * 0.6) {
            Image(systemName: icon)
                .font(.system(size: m.bodySize, weight: .black))
                .foregroundStyle(AppTheme.coral)
                .frame(width: m.bodySize * 1.6)
            Text(text)
                .font(AppTheme.rounded(m.captionSize + 2, .bold))
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    RulesView()
        .appMetrics()
}
