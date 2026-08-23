import Foundation
import Observation

/// De fase van een potje: eerst legt iedereen zijn vloot, dan wordt er
/// geschoten tot één vloot helemaal onder water ligt.
enum GamePhase: String, Codable {
    case placement
    case playing
    case finished
}

@MainActor
@Observable
final class GameEngine {
    let mode: GameMode
    let boardSize: BoardSize
    private(set) var players: [GamePlayer]
    let startingPlayerIndex: Int
    private(set) var currentPlayerIndex: Int
    private(set) var phase: GamePhase
    /// De zee van elke speler, in spelersvolgorde.
    private(set) var boards: [PlayerBoard]
    /// Wie zijn vloot al heeft goedgekeurd; de computer staat meteen klaar.
    private(set) var placementReady: [Bool]
    /// Een misser ligt nog even te kijk; schieten is dan uit.
    private(set) var isResolving = false
    /// De computer "mikt": het bord is even niet aantikbaar.
    private(set) var isThinking = false
    private(set) var isFinished = false
    private(set) var winnerProfileIDs: [UUID] = []
    private(set) var turnMessage: String = ""
    /// Bumps after meaningful state changes so de UI kan autosaven.
    private(set) var saveVersion = 0
    /// True kort nadat de beurt wisselde — UI toont banner of overgavescherm.
    private(set) var turnJustChanged = false
    /// Bumps bij een rake voltreffer; de UI hangt er geluid en haptiek aan.
    private(set) var hitPulse = 0
    /// Bumps bij een plons in het water.
    private(set) var missPulse = 0
    /// Bumps wanneer een hele boot zinkt.
    private(set) var sunkPulse = 0
    /// Aantal schoten over alle spelers heen.
    private(set) var attempts = 0
    /// Schoten per speler, in spelersvolgorde.
    private(set) var shotsFired: [Int]
    /// Het laatste schot, voor een korte highlight op het bord.
    private(set) var lastShot: Coord?
    /// De zee waarop dat schot viel; de highlight hoort alleen daar.
    private(set) var lastShotBoardIndex: Int?

    private var rng: SplitMix64
    /// Het vizier van de computerspeler; leeft zolang dit potje leeft.
    private let computerAI = ComputerAI()

    var currentPlayer: GamePlayer { players[currentPlayerIndex] }
    var opponentIndex: Int { (currentPlayerIndex + 1) % max(players.count, 1) }

    private var computerLevel: ComputerLevel? {
        players.first(where: \.isComputer)?.computerLevel
    }

    var canFire: Bool {
        phase == .playing && !isFinished && !isResolving && !isThinking && !currentPlayer.isComputer
    }

    /// Wie er nu zijn vloot ligt te schikken; `nil` zodra iedereen klaar is.
    var arrangingPlayerIndex: Int? {
        placementReady.firstIndex(of: false)
    }

    /// Aantal rake schoten dat deze speler loste — de treffers óp de zee
    /// van de ander.
    func hitCount(of playerIndex: Int) -> Int {
        let other = (playerIndex + 1) % players.count
        return boards.indices.contains(other) ? boards[other].hitCount : 0
    }

    /// Aantal boten dat deze speler al liet zinken.
    func shipsSunk(by playerIndex: Int) -> Int {
        let other = (playerIndex + 1) % players.count
        guard boards.indices.contains(other) else { return 0 }
        return boards[other].ships.count(where: \.isSunk)
    }

    var snapshot: GameSnapshot {
        GameSnapshot(
            mode: mode,
            boardSize: boardSize,
            players: players,
            startingPlayerIndex: startingPlayerIndex,
            currentPlayerIndex: currentPlayerIndex,
            phase: phase,
            boards: boards,
            placementReady: placementReady,
            shotsFired: shotsFired,
            turnMessage: turnMessage,
            savedAt: .now
        )
    }

    init(
        mode: GameMode,
        profiles: [PlayerProfile],
        boardSize: BoardSize = .medium,
        startingPlayerIndex: Int = 0,
        seed: UInt64? = nil
    ) {
        self.mode = mode
        self.boardSize = boardSize
        self.players = profiles.map(GamePlayer.init)
        self.startingPlayerIndex = min(max(startingPlayerIndex, 0), max(profiles.count - 1, 0))
        self.currentPlayerIndex = self.startingPlayerIndex
        var rng = SplitMix64(seed: seed ?? UInt64.random(in: .min ... .max))
        self.boards = profiles.map { _ in boardSize.placeFleet(using: &rng) }
        // De computer legt zijn vloot meteen; mensen mogen eerst husselen.
        self.placementReady = profiles.map(\.isComputer)
        self.shotsFired = profiles.map { _ in 0 }
        self.phase = .placement
        self.rng = rng
        if let first = placementReady.firstIndex(of: false) {
            self.turnMessage = String(localized: "\(players[first].name) legt de vloot klaar")
        } else {
            self.phase = .playing
            self.turnMessage = String(localized: "\(currentPlayer.name) mag beginnen")
        }
    }

    init(snapshot: GameSnapshot, seed: UInt64? = nil) {
        self.mode = snapshot.mode
        self.boardSize = snapshot.boardSize
        self.players = snapshot.players
        self.startingPlayerIndex = min(max(snapshot.startingPlayerIndex, 0), max(snapshot.players.count - 1, 0))
        self.currentPlayerIndex = min(max(snapshot.currentPlayerIndex, 0), max(snapshot.players.count - 1, 0))
        self.phase = snapshot.phase
        self.boards = snapshot.boards
        self.placementReady = snapshot.placementReady
        self.shotsFired = snapshot.shotsFired
        self.attempts = snapshot.shotsFired.reduce(0, +)
        self.rng = SplitMix64(seed: seed ?? UInt64.random(in: .min ... .max))
        self.turnMessage = snapshot.turnMessage

        // De computer kent na een hervatting zijn vizier niet meer; hij
        // leert zijn rake schoten opnieuw uit het bord van de tegenstander.
        if let humanIndex = players.firstIndex(where: { !$0.isComputer }),
           players.contains(where: \.isComputer) {
            computerAI.relearn(board: boards[humanIndex])
        }

        // Een bewaard spel dat toch al uit was, netjes afronden in plaats
        // van laten doorspelen.
        if boards.contains(where: \.allSunk) {
            finishGame()
        }
    }

    // MARK: - Vloot leggen

    /// Legt de vloot van de schikkende speler opnieuw. Meldt of er echt
    /// iets gebeurde, zodat de UI geen geluid afvuurt bij een loze tik.
    @discardableResult
    func shuffleFleet() -> Bool {
        guard phase == .placement, let index = arrangingPlayerIndex else { return false }
        boards[index] = boardSize.placeFleet(using: &rng)
        markDirty()
        return true
    }

    /// De schikkende speler is tevreden. Zodra iedereen klaar is, begint
    /// het schieten.
    func confirmFleet() {
        guard phase == .placement, let index = arrangingPlayerIndex else { return }
        placementReady[index] = true
        if let next = arrangingPlayerIndex {
            turnMessage = String(localized: "\(players[next].name) legt de vloot klaar")
            turnJustChanged = true
        } else {
            phase = .playing
            turnMessage = String(localized: "\(currentPlayer.name) mag beginnen")
            turnJustChanged = true
        }
        markDirty()
    }

    // MARK: - Schieten

    /// Vuurt een schot af voor de speler aan zet. Meldt of er echt iets
    /// gebeurde: op een beschoten vakje nóg eens tikken kost geen beurt.
    @discardableResult
    func fire(at coord: Coord) -> Bool {
        guard canFire else { return false }
        return shoot(at: coord)
    }

    /// Rondt een misser af en geeft de beurt door. De UI (of de
    /// computerlus) roept dit aan nadat de speler de plons even zag.
    func finishMiss() {
        guard isResolving else { return }
        isResolving = false
        advanceTurn()
        markDirty()
    }

    func acknowledgeTurnChange() {
        turnJustChanged = false
    }

    func playComputerTurnIfNeeded() async {
        // Expliciet annuleerbaar: als het spel dichtgaat stopt de lus, in
        // plaats van in de achtergrond het potje uit te spelen.
        while !Task.isCancelled, phase == .playing, !isFinished, currentPlayer.isComputer {
            isThinking = true
            turnMessage = String(localized: "\(currentPlayer.name) mikt…")
            try? await Task.sleep(for: .milliseconds(1000))
            guard !Task.isCancelled, !isFinished, currentPlayer.isComputer else {
                isThinking = false
                return
            }
            let level = currentPlayer.computerLevel ?? .medium
            let target = boards[opponentIndex]
            guard let coord = computerAI.chooseShot(
                gridSize: target.gridSize,
                shots: target.shots,
                level: level,
                using: &rng
            ) else {
                isThinking = false
                return
            }
            isThinking = false
            shoot(at: coord)
            if isResolving {
                // Ook een kind wil de plons van de computer even zien.
                try? await Task.sleep(for: .milliseconds(1300))
                guard !Task.isCancelled else { return }
                finishMiss()
            } else {
                // Raak: even laten binnenkomen, daarna schiet hij nog eens.
                try? await Task.sleep(for: .milliseconds(1100))
            }
        }
    }

    /// De deelnemers van dit spel als profielen, voor een rematch met
    /// dezelfde spelers en hetzelfde computerniveau.
    func rematchProfiles() -> [PlayerProfile] {
        players.map { player in
            PlayerProfile(
                id: player.profileID,
                name: player.name,
                avatarColorIndex: player.avatarColorIndex,
                avatarSymbol: player.avatarSymbol,
                computerLevel: player.computerLevel
            )
        }
    }

    // MARK: - Privé

    /// Lost een schot, voor mens én computer, en beoordeelt het resultaat.
    @discardableResult
    private func shoot(at coord: Coord) -> Bool {
        guard phase == .playing else { return false }
        let targetIndex = opponentIndex
        guard let result = boards[targetIndex].receiveShot(at: coord) else { return false }

        attempts += 1
        shotsFired[currentPlayerIndex] += 1
        lastShot = coord
        lastShotBoardIndex = targetIndex
        // De computer leert van elk eigen schot — nooit van de vloot zelf,
        // dus gluren onder water kan hij niet.
        if currentPlayer.isComputer, let computerLevel {
            computerAI.note(result: result, at: coord, level: computerLevel, using: &rng)
        }

        switch result {
        case .miss:
            missPulse += 1
            isResolving = true
            turnMessage = String(localized: "Mis — plons in het water…")
        case .hit:
            hitPulse += 1
            turnMessage = String(localized: "Raak! \(currentPlayer.name) mag nog een keer")
        case .sunk(let kind):
            sunkPulse += 1
            if boards[targetIndex].allSunk {
                finishGame()
            } else {
                turnMessage = String(localized: "De \(kind.title) is gezonken! Nog een keer!")
            }
        }
        markDirty()
        return true
    }

    private func advanceTurn() {
        currentPlayerIndex = opponentIndex
        turnMessage = String(localized: "\(currentPlayer.name) is aan de beurt")
        turnJustChanged = true
    }

    private func finishGame() {
        phase = .finished
        isFinished = true
        isResolving = false
        // De winnaar is wie de zee van de ander leegschoot — ook na een
        // hervatting klopt dat, wat de beurtstand ook zegt.
        if let winnerIndex = players.indices.first(where: { index in
            let other = (index + 1) % players.count
            return boards[other].allSunk
        }) {
            let winner = players[winnerIndex]
            winnerProfileIDs = [winner.profileID]
            turnMessage = String(localized: "\(winner.name) wint — de hele vloot is gezonken!")
        }
    }

    private func markDirty() {
        saveVersion += 1
    }
}
