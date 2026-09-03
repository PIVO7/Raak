import SwiftUI

struct HomeView: View {
    @Environment(ProfileStore.self) private var profileStore
    @Environment(GameStore.self) private var gameStore
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.metrics) private var m
    @State private var activeGame: ActiveGame?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground()

                // De zee onder aan het scherm; decor achter de inhoud, tot
                // voorbij de veilige zone zodat hij de rand raakt.
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    SeaBandView(amplitude: m.gutter * 0.65, lineWidth: m.border, height: m.gutter * 6)
                }
                .ignoresSafeArea(edges: .bottom)

                // De inhoud vult minstens het scherm, zodat de menupillen
                // net boven de zee eindigen in plaats van halverwege.
                GeometryReader { geo in
                    ScrollView {
                        VStack(spacing: 0) {
                            // De held zakt een stuk in de golfband: het
                            // bootje ligt ín het water en de golflijn loopt
                            // er achter door in plaats van eronder langs.
                            VStack(spacing: -m.gutter * 0.5) {
                                HomeHeroView()
                                    .offset(y: m.gutter * 1.1)
                                    .zIndex(1)

                                WavyBandView(amplitude: m.gutter * 0.8, lineWidth: m.border) {
                                    VStack(spacing: 8) {
                                        // De merknaam vertaalt niet mee; de
                                        // uitroep "Raak!" in het spel wél.
                                        Text(verbatim: "Raak!")
                                            .font(AppTheme.rounded(m.brandSize * 0.82))
                                            .foregroundStyle(AppTheme.ink)
                                            .minimumScaleFactor(0.6)
                                            .lineLimit(1)

                                        Text("Zink de vloot en roep: Raak!")
                                            .font(AppTheme.rounded(m.bodySize, .bold))
                                            .foregroundStyle(AppTheme.cardSoft)
                                    }
                                }
                            }
                            .padding(.top, m.gutter * 1.6)
                            .padding(.bottom, m.gutter * 1.5)

                            // Beperkte ademruimte onder de band: de kaarten
                            // sluiten aan bij de titel, en de resterende
                            // lucht valt onder de pillen — open zee in
                            // plaats van een gat midden in het scherm.
                            Spacer(minLength: 0)
                                .frame(maxHeight: m.gutter * 2.5)

                            VStack(spacing: m.gutter) {
                                if let saved = gameStore.savedGame {
                                    Button {
                                        activeGame = ActiveGame(engine: GameEngine(snapshot: saved))
                                    } label: {
                                        menuLabel(
                                            String(localized: "Verder spelen"),
                                            subtitle: saved.summaryTitle,
                                            tint: AppTheme.coral,
                                            cardFill: AppTheme.tintCoral,
                                            symbol: "sailboat.fill",
                                            symbolColorIndex: 1,
                                            badge: String(localized: "Lopend spel")
                                        )
                                    }
                                }

                                NavigationLink(value: Destination.setup(.versusFriends)) {
                                    menuLabel(GameMode.versusFriends.title,
                                              subtitle: String(localized: "2 spelers, één toestel"),
                                              tint: AppTheme.amber, cardFill: AppTheme.tintAmber,
                                              symbol: "person.2.fill", symbolColorIndex: 0)
                                }
                                NavigationLink(value: Destination.setup(.versusComputer)) {
                                    menuLabel(GameMode.versusComputer.title,
                                              subtitle: String(localized: "Solo uitdaging"),
                                              tint: AppTheme.sky, cardFill: AppTheme.tintSky,
                                              symbol: "target", symbolColorIndex: 2)
                                }
                            }
                            .padding(.horizontal, m.gutter * 1.5)

                            // Beheer hoort niet tussen de spelmodi: twee
                            // rustige pillen onder de speelkaarten.
                            HStack(spacing: m.gutter * 0.85) {
                                NavigationLink(value: Destination.profiles) {
                                    pillLabel(String(localized: "Profielen"),
                                              symbol: "person.crop.circle.fill",
                                              color: AvatarBadge.palette[4])
                                }
                                .accessibilityLabel(Text(verbatim: "\(String(localized: "Profielen")), \(winsSubtitle)"))

                                NavigationLink(value: Destination.statistics) {
                                    pillLabel(String(localized: "Statistieken"),
                                              symbol: "trophy.fill",
                                              color: AvatarBadge.palette[5])
                                }
                                .accessibilityLabel(Text(verbatim: "\(String(localized: "Statistieken")), \(String(localized: "Trofeeën en records"))"))
                            }
                            .padding(.horizontal, m.gutter * 1.5)
                            .padding(.top, m.gutter * 1.2)

                            Spacer(minLength: 0)

                            // De zee blijft vrij van knoppen: vaste marge ter
                            // hoogte van de golfband, ook als de spacers
                            // dichtklappen op kleine schermen.
                            Color.clear.frame(height: m.gutter * 7)
                        }
                        .frame(maxWidth: m.contentMaxWidth)
                        .frame(maxWidth: .infinity, minHeight: geo.size.height)
                    }
                }
            }
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .profiles:
                    ProfilesView()
                case .setup(let mode):
                    GameSetupView(mode: mode)
                case .stats(let profileID):
                    ProfileStatsView(profileID: profileID)
                case .familyRecords:
                    FamilyRecordsView()
                case .statistics:
                    StatsOverviewView()
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            // Rechtsboven, buiten de meeloop van de menutegels: instellingen
            // zijn voor de ouders, niet voor het spel.
            .overlay(alignment: .topTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Label("Instellingen", systemImage: "gearshape.fill")
                        .labelStyle(.iconOnly)
                        .font(.system(size: m.captionSize + 3, weight: .black))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: m.tapTarget, height: m.tapTarget)
                }
                .buttonStyle(ToyButtonStyle(fill: AppTheme.card, radius: m.cellCorner, depth: m.shallowDepth, border: m.thinBorder))
                .padding(.trailing, m.gutter * 1.5)
                .padding(.top, m.gutter * 0.5)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(entitlements: entitlements)
                    .appMetrics()
            }
            .fullScreenCover(item: $activeGame) { game in
                GameCoverView(
                    game: game,
                    profileStore: profileStore,
                    gameStore: gameStore,
                    activeGame: $activeGame
                )
            }
        }
        .tint(AppTheme.coral)
        .onAppear(perform: startDemoResultIfRequested)
    }

    /// DEBUG-hulp voor demo's en screenshots: start de app met `-demoResult`
    /// om meteen een uitgespeeld potje te openen, inclusief de volledige
    /// eindstand-choreografie. Losse profielen, dus echte spelersdata blijft
    /// onaangeroerd.
    private func startDemoResultIfRequested() {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-demoResult"),
              activeGame == nil else { return }
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
        for ship in engine.boards[1].ships {
            for cell in ship.cells {
                engine.fire(at: cell)
            }
        }
        activeGame = ActiveGame(engine: engine)
        #endif
    }

    private var winsSubtitle: String {
        let total = profileStore.humanProfiles.reduce(0) { $0 + $1.wins }
        if profileStore.humanProfiles.isEmpty {
            return String(localized: "Maak eerst een speler aan")
        }
        return String(localized: "\(profileStore.humanProfiles.count) spelers · \(total) overwinningen")
    }

    private func menuLabel(_ title: String, subtitle: String, tint: Color, cardFill: Color, symbol: String, symbolColorIndex: Int, badge: String? = nil) -> some View {
        HStack(spacing: m.gutter) {
            TileBadge(symbol: symbol, colorIndex: symbolColorIndex, size: m.avatarSize * 0.66)
                .frame(width: m.avatarSize + 2, height: m.avatarSize + 2)
                .toyBlock(fill: tint, radius: m.cellCorner, depth: 0, border: m.thinBorder + 0.5)

            VStack(alignment: .leading, spacing: 3) {
                if let badge {
                    Text(badge)
                        .textCase(.uppercase)
                        .font(AppTheme.rounded(m.captionSize - 2))
                        .kerning(0.6)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(tint))
                        .overlay(Capsule().strokeBorder(AppTheme.ink, lineWidth: m.thinBorder))
                        .padding(.bottom, 2)
                }
                Text(title)
                    .font(AppTheme.rounded(m.bodySize + 3))
                    .foregroundStyle(AppTheme.ink)
                Text(subtitle)
                    .font(AppTheme.rounded(m.captionSize, .bold))
                    .foregroundStyle(AppTheme.cardSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: m.bodySize * 0.9, weight: .black))
                .foregroundStyle(AppTheme.cardDim)
        }
        .padding(m.gutter)
        .toyBlock(fill: cardFill, radius: m.cardCorner, depth: m.depth, border: m.border)
    }

    /// Beheer als capsule in plaats van kaart: bewust kleiner dan de
    /// spelmodi, want spelen gaat voor.
    private func pillLabel(_ title: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: m.bodySize * 0.95, weight: .black))
                .foregroundStyle(color)
            Text(title)
                .font(AppTheme.rounded(m.bodySize - 2, .heavy))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: m.tapTarget)
        .background(Capsule().fill(AppTheme.card))
        .overlay(Capsule().strokeBorder(AppTheme.ink, lineWidth: m.thinBorder + 0.5))
        .background(Capsule().fill(AppTheme.ink).offset(y: 3))
    }
}

#Preview {
    // Tijdelijke bestanden, zodat de preview nooit aan echte spelersdata komt.
    let profiles = ProfileStore(fileURL: URL.temporaryDirectory.appending(path: "preview-\(UUID()).json"))
    let _ = profiles.addProfile(name: "Lene")
    let _ = profiles.addProfile(name: "Ellis")

    HomeView()
        .environment(profiles)
        .environment(GameStore(fileURL: URL.temporaryDirectory.appending(path: "preview-\(UUID()).json")))
        .environment(EntitlementStore(previewUnlocked: false))
        .appMetrics()
}
