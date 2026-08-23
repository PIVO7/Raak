import SwiftUI

/// Het anker van het startscherm: een zeilbootje en een vizier boven de
/// titel. Tikken lost een schot: het vizier wordt een voltreffer en het
/// bootje wiebelt — puur voor de fun.
struct HomeHeroView: View {
    @Environment(\.metrics) private var m
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hit = false
    @State private var wiggle = 0

    var body: some View {
        Button(action: fire) {
            HStack(spacing: -m.discSize * 0.18) {
                TileBadge(symbol: "sailboat.fill", colorIndex: 1, size: m.discSize * 1.15)
                    .rotationEffect(.degrees(hit ? -14 : -9))
                    .zIndex(1)
                TileBadge(symbol: hit ? "burst.fill" : "target", colorIndex: hit ? 2 : 0, size: m.discSize * 1.15)
                    .rotationEffect(.degrees(8))
                    .offset(y: m.discSize * 0.16)
            }
            .rotationEffect(.degrees(wiggle.isMultiple(of: 2) ? 0 : 3))
            .animation(.spring(response: 0.3, dampingFraction: 0.35), value: wiggle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Een zeilbootje en een vizier")
        .accessibilityHint("Tik om een schot te lossen")
    }

    private func fire() {
        hit.toggle()
        if !reduceMotion {
            wiggle += 1
        }
        SoundPlayer.shared.play(hit ? .score : .drop)
    }
}

#Preview {
    HomeHeroView()
        .padding(40)
        .background(AppTheme.cream)
        .appMetrics()
}
