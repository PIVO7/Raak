import Foundation

/// Serialiseerbare snapshot van een lopend spel, zodat kids kunnen hervatten.
struct GameSnapshot: Codable, Equatable {
    var mode: GameMode
    var boardSize: BoardSize
    var players: [GamePlayer]
    var startingPlayerIndex: Int
    var currentPlayerIndex: Int
    var phase: GamePhase
    var boards: [PlayerBoard]
    var placementReady: [Bool]
    var shotsFired: [Int]
    var turnMessage: String
    var savedAt: Date

    /// Alleen een geldig, nog niet afgelopen spel is het hervatten waard.
    var isResumable: Bool {
        guard players.count == 2,
              boards.count == 2,
              placementReady.count == 2,
              shotsFired.count == 2,
              (0..<players.count).contains(startingPlayerIndex),
              (0..<players.count).contains(currentPlayerIndex),
              phase != .finished,
              !boards.contains(where: \.allSunk) else {
            return false
        }
        // Elke zee hoort een complete vloot binnen de randen te dragen, en
        // rake schoten horen ook echt als schot geregistreerd te staan.
        return boards.allSatisfy { board in
            board.gridSize == boardSize.gridSize
                && board.ships.map(\.kind).sorted(by: { $0.rawValue < $1.rawValue })
                    == boardSize.fleet.sorted(by: { $0.rawValue < $1.rawValue })
                && board.ships.allSatisfy { ship in
                    ship.cells.count == ship.kind.length
                        && ship.cells.allSatisfy {
                            (0..<board.gridSize).contains($0.row) && (0..<board.gridSize).contains($0.col)
                        }
                        && ship.hits.isSubset(of: Set(ship.cells))
                        && ship.hits.isSubset(of: board.shots)
                }
        }
    }

    var summaryTitle: String {
        let names = players.filter { !$0.isComputer }.map(\.name)
        switch mode {
        case .versusComputer:
            return names.first.map { String(localized: "\($0) vs Computer") } ?? mode.title
        case .versusFriends:
            return names.joined(separator: " · ")
        }
    }
}
