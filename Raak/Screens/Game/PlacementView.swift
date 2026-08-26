import SwiftUI

/// De vloot klaarleggen: het eigen bord groot in beeld, met schudden tot
/// het bevalt. Slepen hoeft niet — één tik op de schudknop legt alles
/// opnieuw, precies genoeg controle voor kleine handen.
struct PlacementView: View {
    let engine: GameEngine
    /// De speler die nu aan het schikken is.
    let playerIndex: Int
    let onClose: () -> Void

    @Environment(\.metrics) private var m
    @State private var shufflePulse = 0

    private var player: GamePlayer { engine.players[playerIndex] }

    var body: some View {
        VStack(spacing: m.gutter) {
            HStack(spacing: 8) {
                Text("Vloot klaarleggen")
                    .textCase(.uppercase)
                    .font(AppTheme.rounded(m.captionSize * 0.92))
                    .kerning(1.6)
                    .foregroundStyle(AppTheme.faint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 4)

                Button(action: onClose) {
                    Label("Spel verlaten", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                        .font(.system(size: m.captionSize + 2, weight: .black))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: m.tapTarget, height: m.tapTarget)
                }
                .buttonStyle(ToyButtonStyle(fill: AppTheme.card, radius: m.cellCorner, depth: 3, border: m.thinBorder))
            }

            VStack(spacing: 4) {
                HStack(spacing: m.gutter * 0.5) {
                    AvatarBadge(player: player, size: m.avatarSize * 0.7)
                    Text("\(player.name), leg je vloot klaar")
                        .font(AppTheme.rounded(m.bodySize + 2))
                        .foregroundStyle(AppTheme.headline)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                Text("Schud tot je zee je bevalt — de ander mag niet kijken!")
                    .font(AppTheme.rounded(m.captionSize, .bold))
                    .foregroundStyle(AppTheme.soft)
                    .multilineTextAlignment(.center)
            }

            BoardGridView(
                board: engine.boards[playerIndex],
                showsShips: true,
                isEnabled: false
            )

            FleetLegendView(ships: engine.boards[playerIndex].ships)

            HStack(spacing: m.gutter) {
                Button {
                    if engine.shuffleFleet() {
                        shufflePulse += 1
                        SoundPlayer.shared.play(.drop)
                    }
                } label: {
                    Label("Schud", systemImage: "dice.fill")
                        .font(AppTheme.rounded(m.buttonTextSize * 0.75))
                        .foregroundStyle(AppTheme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: m.buttonHeight * 0.9)
                }
                .buttonStyle(ToyButtonStyle(
                    fill: AppTheme.amber,
                    radius: m.cardCorner * 0.8,
                    depth: m.depth,
                    border: m.border
                ))

                Button {
                    SoundPlayer.shared.play(.score)
                    engine.confirmFleet()
                } label: {
                    Label("Klaar!", systemImage: "checkmark")
                        .font(AppTheme.rounded(m.buttonTextSize * 0.75))
                        .foregroundStyle(AppTheme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: m.buttonHeight * 0.9)
                }
                .buttonStyle(ToyButtonStyle(
                    fill: AppTheme.mint,
                    radius: m.cardCorner * 0.8,
                    depth: m.depth,
                    border: m.border
                ))
            }
            .padding(.bottom, 4)
        }
        .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.7), trigger: shufflePulse)
    }
}

#Preview {
    let profiles = [
        PlayerProfile(name: "Lene", avatarColorIndex: 0),
        PlayerProfile(name: "Ellis", avatarColorIndex: 1)
    ]
    PlacementView(
        engine: GameEngine(mode: .versusFriends, profiles: profiles),
        playerIndex: 0,
        onClose: {}
    )
    .padding()
    .background(AppTheme.cream)
    .appMetrics()
}
