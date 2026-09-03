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
            ThemedBackground()

            VStack(spacing: m.gutter * 1.2) {
                AvatarBadge(player: player, size: m.avatarSize * 1.6)

                Text("Geef het toestel aan \(player.name)")
                    .font(AppTheme.rounded(m.titleSize * 0.55))
                    .foregroundStyle(AppTheme.headline)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)

                Text(title)
                    .font(AppTheme.rounded(m.bodySize, .bold))
                    .foregroundStyle(AppTheme.soft)
                    .multilineTextAlignment(.center)

                Button(action: onReady) {
                    Text(buttonTitle)
                        .font(AppTheme.rounded(m.heroButton.textSize))
                        .foregroundStyle(AppTheme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: m.heroButton.height)
                }
                .buttonStyle(ToyButtonStyle(
                    fill: AppTheme.mint,
                    radius: m.buttonCorner,
                    depth: m.heroDepth,
                    border: m.border
                ))
                .padding(.top, m.gutter)
            }
            .padding(m.gutter * 2)
            .frame(maxWidth: m.overlayMaxWidth)
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
