import SwiftUI

/// Houdt het spel bij elkaar: bewaart de voortgang en vertaalt schoten naar
/// trillingen, banners en vieringen. Het tekenwerk zit in de losse views.
///
/// Aan één toestel zijn de zeeën geheim; het overgavescherm dekt daarom bij
/// elke beurtwissel alles af tot de volgende speler klaar zit.
struct GameView: View {
    let engine: GameEngine
    /// Vervangt het spel door een vers potje met dezelfde deelnemers; de
    /// eigenaar van de cover wisselt de engine.
    let onRematch: () -> Void
    let onClose: () -> Void

    @Environment(ProfileStore.self) private var profileStore
    @Environment(GameStore.self) private var gameStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.metrics) private var m

    @State private var didRecordResult = false
    @State private var isNewRecord = false
    @State private var showResult = false
    @State private var showTurnBanner = false
    /// Het overgavescherm aan één toestel; dekt de geheime zeeën af.
    @State private var showHandover = false
    @State private var showExitConfirm = false
    @State private var bannerDismissal: Task<Void, Never>?
    @State private var resultReveal: Task<Void, Never>?
    /// Geeft na een misser de beurt door zodra het kind de plons zag; de
    /// computerlus regelt zijn eigen missers.
    @State private var resolveDelay: Task<Void, Never>?
    @State private var shotPulse = 0
    @State private var turnPulse = 0
    @State private var winPulse = 0

    /// Wie er naar het scherm hoort te kijken: solo altijd de mens, aan één
    /// toestel wie er schikt of aan de beurt is.
    private var viewerIndex: Int {
        if engine.mode == .versusComputer {
            return engine.players.firstIndex { !$0.isComputer } ?? 0
        }
        if engine.phase == .placement {
            return engine.arrangingPlayerIndex ?? 0
        }
        return engine.currentPlayerIndex
    }

    private var targetIndex: Int { (viewerIndex + 1) % max(engine.players.count, 1) }

    /// Aan één toestel zijn beide spelers mensen en is elk bord geheim.
    private var needsPrivacy: Bool { engine.mode == .versusFriends }

    var body: some View {
        ZStack {
            ThemedBackground()

            Group {
                if engine.phase == .placement, let arranging = engine.arrangingPlayerIndex {
                    PlacementView(engine: engine, playerIndex: arranging, onClose: requestLeave)
                } else {
                    battleContent
                }
            }
            .padding(.horizontal, m.gutter)
            .padding(.vertical, m.gutter * 0.5)
            // De hele kolom op één maximumbreedte, anders rekt de kop op een
            // iPad uit over het volle scherm.
            .frame(maxWidth: m.contentMaxWidth)
            .frame(maxWidth: .infinity)

            if showTurnBanner {
                TurnBannerView(player: engine.currentPlayer, title: bannerTitle)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .move(edge: .top).combined(with: .opacity)
                    )
                    .zIndex(2)
            }

            if showHandover {
                HandoverView(
                    player: handoverPlayer,
                    title: handoverTitle,
                    buttonTitle: String(localized: "Ik zit klaar!"),
                    onReady: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showHandover = false
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(3)
            }

            if showResult {
                GameResultOverlay(
                    players: engine.players,
                    winnerProfileIDs: engine.winnerProfileIDs,
                    message: engine.turnMessage,
                    hitCounts: engine.players.indices.map(engine.hitCount(of:)),
                    shipsSunk: engine.players.indices.map(engine.shipsSunk(by:)),
                    isNewRecord: isNewRecord,
                    onRematch: onRematch,
                    onClose: onClose
                )
                .zIndex(4)
            }

            if showExitConfirm {
                ToyDialog(
                    title: String(localized: "Spel verlaten?"),
                    message: String(localized: "Je voortgang wordt bewaard."),
                    confirmTitle: String(localized: "Verlaten"),
                    cancelTitle: String(localized: "Doorspelen"),
                    onConfirm: leave,
                    onCancel: {
                        withAnimation(.easeOut(duration: 0.15)) {
                            showExitConfirm = false
                        }
                    }
                )
                .zIndex(5)
            }
        }
        .task(id: engine.currentPlayerIndex) {
            await engine.playComputerTurnIfNeeded()
        }
        .onAppear {
            if engine.isFinished {
                // Een hervat spel dat toch al uit bleek: meteen de eindstand.
                showResult = true
            } else if needsPrivacy {
                // Ook bij de start: zo komt het toestel gegarandeerd bij de
                // juiste speler terecht, ook na een hervatting.
                showHandover = true
            }
        }
        .onChange(of: engine.saveVersion) { _, _ in
            persistProgress()
        }
        .onChange(of: engine.hitPulse) { _, _ in
            winPulse += 1
            SoundPlayer.shared.play(.score)
            AccessibilityNotification.Announcement(String(localized: "Raak!")).post()
        }
        .onChange(of: engine.missPulse) { _, _ in
            shotPulse += 1
            SoundPlayer.shared.play(.drop)
            AccessibilityNotification.Announcement(String(localized: "Mis, plons in het water")).post()
        }
        .onChange(of: engine.sunkPulse) { _, _ in
            winPulse += 1
            SoundPlayer.shared.play(.score)
            AccessibilityNotification.Announcement(engine.turnMessage).post()
        }
        .onChange(of: engine.isResolving) { _, resolving in
            resolveDelay?.cancel()
            guard resolving, !engine.currentPlayer.isComputer else { return }
            resolveDelay = Task {
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 1000 : 1300))
                guard !Task.isCancelled else { return }
                engine.finishMiss()
            }
        }
        .onChange(of: engine.isFinished) { _, finished in
            guard finished else { return }
            gameDidFinish()
        }
        .onChange(of: engine.turnJustChanged) { _, changed in
            guard changed else { return }
            presentTurnChange()
            engine.acknowledgeTurnChange()
        }
        .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.7), trigger: shotPulse)
        .sensoryFeedback(.selection, trigger: turnPulse)
        .sensoryFeedback(.success, trigger: winPulse)
    }

    // MARK: - Deelviews

    /// Het schietscherm: de vijandelijke zee groot om op te mikken, de eigen
    /// zee klein ter controle eronder.
    private var battleContent: some View {
        VStack(spacing: m.gutter * 0.7) {
            topBar

            GameHeaderView(
                players: engine.players,
                currentPlayerID: engine.currentPlayer.id,
                hitCount: engine.hitCount(of:)
            )

            statusLine

            BoardGridView(
                board: engine.boards[targetIndex],
                showsShips: false,
                isEnabled: engine.canFire && viewerIndex == engine.currentPlayerIndex,
                lastShot: engine.lastShotBoardIndex == targetIndex ? engine.lastShot : nil,
                onFire: { engine.fire(at: $0) }
            )

            FleetLegendView(ships: engine.boards[targetIndex].ships)

            Text("JOUW ZEE")
                .font(AppTheme.rounded(m.captionSize * 0.82))
                .kerning(1.4)
                .foregroundStyle(AppTheme.faint)

            BoardGridView(
                board: engine.boards[viewerIndex],
                showsShips: true,
                isEnabled: false
            )
            .frame(height: m.discSize * 2.6)
        }
    }

    /// De spelstand onder de kop: wie er mag, raak of mis. Tijdens de banner
    /// en het eindscherm wijkt hij.
    private var statusLine: some View {
        Text(engine.turnMessage)
            .font(AppTheme.rounded(m.bodySize, .bold))
            .foregroundStyle(AppTheme.soft)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .opacity(showResult || showTurnBanner ? 0 : 1)
    }

    /// De dunne bovenrand: schot- en botenteller (passieve meta-info) met
    /// de sluitknop ernaast.
    private var topBar: some View {
        HStack(spacing: 8) {
            (Text("Schot \(engine.attempts + (engine.isFinished ? 0 : 1))")
                + Text(verbatim: " · ")
                + Text("Nog \(engine.boards[targetIndex].shipsAfloat) boten"))
                .textCase(.uppercase)
                .font(AppTheme.rounded(m.captionSize * 0.92))
                .kerning(1.6)
                .foregroundStyle(AppTheme.faint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)

            Button(action: requestLeave) {
                Label("Spel verlaten", systemImage: "xmark")
                    .labelStyle(.iconOnly)
                    .font(.system(size: m.captionSize + 2, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: m.tapTarget, height: m.tapTarget)
            }
            .buttonStyle(ToyButtonStyle(fill: AppTheme.card, radius: m.cellCorner, depth: 3, border: m.thinBorder))
        }
    }

    // MARK: - Zetten

    /// Een afgelopen spel valt niets meer te bewaren, dus dan slaan we de
    /// bevestiging over.
    private func requestLeave() {
        if engine.isFinished {
            leave()
        } else {
            withAnimation(.easeOut(duration: 0.15)) {
                showExitConfirm = true
            }
        }
    }

    private func leave() {
        persistProgress()
        onClose()
    }

    // MARK: - Reacties op het spel

    /// Solo spreekt de banner je aan; met z'n tweeën aan één toestel neemt
    /// het overgavescherm het over.
    private var bannerTitle: String? {
        if engine.mode == .versusComputer, !engine.currentPlayer.isComputer {
            return String(localized: "Jij bent aan de beurt")
        }
        return nil
    }

    /// Wie het toestel moet krijgen: tijdens het vlootleggen de schikker,
    /// daarna wie er mag schieten.
    private var handoverPlayer: GamePlayer {
        if engine.phase == .placement, let arranging = engine.arrangingPlayerIndex {
            return engine.players[arranging]
        }
        return engine.currentPlayer
    }

    private var handoverTitle: String {
        engine.phase == .placement
            ? String(localized: "Leg je vloot klaar — de ander mag niet spieken!")
            : String(localized: "Jouw beurt om te schieten. De zeeën blijven geheim!")
    }

    private func presentTurnChange() {
        guard !engine.isFinished else { return }
        turnPulse += 1
        SoundPlayer.shared.play(.turn)
        if needsPrivacy {
            AccessibilityNotification.Announcement(
                String(localized: "Geef het toestel aan \(handoverPlayer.name)")
            ).post()
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.35, dampingFraction: 0.8)) {
                showHandover = true
            }
            return
        }
        presentTurnBanner()
    }

    private func gameDidFinish() {
        winPulse += 1
        SoundPlayer.shared.play(.fanfare)
        recordResult()
        AccessibilityNotification.Announcement(engine.turnMessage).post()
        // Het zinkende schip eerst even laten zien; daarna pas de eindstand
        // eroverheen.
        resultReveal?.cancel()
        resultReveal = Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 400 : 1200))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.35, dampingFraction: 0.8)) {
                showResult = true
            }
        }
    }

    private func recordResult() {
        guard !didRecordResult else { return }
        didRecordResult = true
        let hitCounts = engine.players.indices.map(engine.hitCount(of:))
        // Record checken vóór de statistieken worden bijgewerkt; het eerste
        // potje ooit telt niet als record.
        if engine.winnerProfileIDs.count == 1,
           let winnerIndex = engine.players.indices.first(where: { engine.winnerProfileIDs.contains(engine.players[$0].profileID) }),
           let profile = profileStore.humanProfiles.first(where: { $0.id == engine.players[winnerIndex].profileID }),
           profile.gamesPlayed > 0,
           hitCounts[winnerIndex] > profile.mostHits {
            isNewRecord = true
        }
        gameStore.clear()
        profileStore.recordGameResult(
            players: engine.players,
            winnerProfileIDs: engine.winnerProfileIDs,
            hitCounts: hitCounts
        )
    }

    private func presentTurnBanner() {
        turnPulse += 1
        AccessibilityNotification.Announcement(
            bannerTitle ?? String(localized: "\(engine.currentPlayer.name) is aan de beurt")
        ).post()

        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.35, dampingFraction: 0.8)) {
            showTurnBanner = true
        }
        // Bij twee snelle beurtwissels zou de timer van de eerste de banner
        // van de tweede verbergen; annuleren voorkomt dat.
        bannerDismissal?.cancel()
        bannerDismissal = Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 700 : 1100))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                showTurnBanner = false
            }
        }
    }

    private func persistProgress() {
        if engine.isFinished {
            gameStore.clear()
        } else {
            gameStore.save(engine.snapshot)
        }
    }
}

#Preview {
    let profiles = [
        PlayerProfile(name: "Lene", avatarColorIndex: 0),
        PlayerProfile(name: "Ellis", avatarColorIndex: 1)
    ]
    GameView(
        engine: GameEngine(mode: .versusFriends, profiles: profiles),
        onRematch: {},
        onClose: {}
    )
    .environment(ProfileStore(fileURL: URL.temporaryDirectory.appending(path: "preview-\(UUID()).json")))
    .environment(GameStore(fileURL: URL.temporaryDirectory.appending(path: "preview-\(UUID()).json")))
    .appMetrics()
}
