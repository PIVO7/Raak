import SwiftUI

/// Het overgavescherm tussen twee beurten aan één toestel: dekt de borden
/// volledig af (de zeeën zijn geheim!) tot de volgende speler klaar zit.
/// Daarom een dichte achtergrond en geen doorschijnend paneel.
struct HandoverView: View {
    let player: GamePlayer
    let title: String
    let buttonTitle: String
    let onReady: () -> Void

    @Environment(\.metrics) private var m

    var body: some View {
        ZStack {
            // Volledig dekkend: de zeeën zijn geheim tot de volgende speler
            // klaar zit. De kaart erop is dezelfde als het doorgeefscherm
            // van Dobbel.
            ThemedBackground()
                .accessibilityHidden(true)

            VStack(spacing: m.gutter) {
                AvatarBadge(player: player, size: m.avatarSize * 1.5)
                    .padding(.top, m.gutter * 0.4)

                Text("Geef door aan \(player.name)")
                    .font(AppTheme.rounded(m.titleSize * 0.6))
                    .foregroundStyle(AppTheme.ink)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)

                Text(title)
                    .font(AppTheme.rounded(m.captionSize + 2, .bold))
                    .foregroundStyle(AppTheme.cardSoft)
                    .multilineTextAlignment(.center)

                Button(action: onReady) {
                    Text(buttonTitle)
                        .font(AppTheme.rounded(m.defaultButton.textSize))
                        .foregroundStyle(AppTheme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: m.defaultButton.height)
                }
                .buttonStyle(ToyButtonStyle(
                    fill: AppTheme.mint,
                    radius: m.buttonCorner,
                    depth: m.defaultButton.depth,
                    border: m.border
                ))
                .padding(.top, 4)
            }
            .padding(m.gutter * 1.4)
            // De kaart in `card` en niet `cream`: in het nachtthema is cream
            // donker en zou de inkt onleesbaar worden.
            .toyBlock(fill: AppTheme.card, radius: m.dialogCorner, depth: m.heroDepth, border: m.border)
            .frame(maxWidth: m.overlayMaxWidth * 0.82)
            .padding(m.gutter * 2)
        }
        // Modaal voor VoiceOver: de borden eronder zijn nu geheim.
        .accessibilityAddTraits(.isModal)
    }
}

#Preview {
    HandoverView(
        player: GamePlayer(profile: PlayerProfile(name: "Ellis", avatarColorIndex: 1)),
        title: "De zeeën blijven geheim — niet spieken!",
        buttonTitle: "Ik zit klaar!",
        onReady: {}
    )
    .appMetrics()
}
