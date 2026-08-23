import XCTest
@testable import Raak

@MainActor
final class GameEngineTests: XCTestCase {
    private func makeEngine(
        mode: GameMode = .versusFriends,
        boardSize: BoardSize = .small,
        seed: UInt64 = 7
    ) -> GameEngine {
        var profiles = [PlayerProfile(name: "Lene")]
        if mode == .versusFriends {
            profiles.append(PlayerProfile(name: "Ellis", avatarColorIndex: 1))
        } else {
            profiles.append(.computer(level: .medium))
        }
        return GameEngine(mode: mode, profiles: profiles, boardSize: boardSize, seed: seed)
    }

    /// Beide vloten goedkeuren zodat het schieten kan beginnen.
    private func confirmFleets(_ engine: GameEngine) {
        while engine.arrangingPlayerIndex != nil {
            engine.confirmFleet()
        }
    }

    /// Een vakje zonder boot op de zee van de tegenstander van de speler
    /// aan zet.
    private func emptyCell(in engine: GameEngine) -> Coord {
        let board = engine.boards[engine.opponentIndex]
        let occupied = Set(board.ships.flatMap(\.cells))
        return (0..<board.gridSize).flatMap { row in
            (0..<board.gridSize).map { Coord(row: row, col: $0) }
        }.first { !occupied.contains($0) && !board.shots.contains($0) }!
    }

    func testPlacementFlowStartsTheGame() {
        let engine = makeEngine()
        XCTAssertEqual(engine.phase, .placement)
        XCTAssertEqual(engine.arrangingPlayerIndex, 0)
        XCTAssertFalse(engine.canFire)

        // Husselen legt een andere zee, maar altijd een geldige vloot.
        let before = engine.boards[0]
        XCTAssertTrue(engine.shuffleFleet())
        XCTAssertEqual(engine.boards[0].ships.count, before.ships.count)

        engine.confirmFleet()
        XCTAssertEqual(engine.arrangingPlayerIndex, 1)
        engine.confirmFleet()
        XCTAssertEqual(engine.phase, .playing)
        XCTAssertTrue(engine.canFire)
    }

    func testComputerFleetIsReadyImmediately() {
        let engine = makeEngine(mode: .versusComputer)
        // Alleen de mens hoeft nog te schikken.
        XCTAssertEqual(engine.arrangingPlayerIndex, 0)
        engine.confirmFleet()
        XCTAssertEqual(engine.phase, .playing)
    }

    func testMissPassesTheTurnAfterResolving() {
        let engine = makeEngine()
        confirmFleets(engine)
        XCTAssertEqual(engine.currentPlayerIndex, 0)

        XCTAssertTrue(engine.fire(at: emptyCell(in: engine)))
        // De plons ligt even te kijk; de beurt is nog niet doorgegeven.
        XCTAssertTrue(engine.isResolving)
        XCTAssertFalse(engine.canFire)
        XCTAssertEqual(engine.currentPlayerIndex, 0)

        engine.finishMiss()
        XCTAssertEqual(engine.currentPlayerIndex, 1)
        XCTAssertTrue(engine.turnJustChanged)
        XCTAssertEqual(engine.attempts, 1)
    }

    func testHitGrantsAnotherShot() {
        let engine = makeEngine()
        confirmFleets(engine)
        let target = engine.boards[1].ships.first { $0.kind.length >= 3 }!

        XCTAssertTrue(engine.fire(at: target.cells[0]))
        XCTAssertFalse(engine.isResolving)
        XCTAssertEqual(engine.currentPlayerIndex, 0)
        XCTAssertTrue(engine.canFire)
        XCTAssertEqual(engine.hitPulse, 1)
        XCTAssertEqual(engine.hitCount(of: 0), 1)
    }

    func testRepeatShotOnSameCellDoesNothing() {
        let engine = makeEngine()
        confirmFleets(engine)
        let cell = emptyCell(in: engine)
        XCTAssertTrue(engine.fire(at: cell))
        engine.finishMiss()
        // De ander schiet ook mis, dan is speler 1 weer aan zet.
        XCTAssertTrue(engine.fire(at: emptyCell(in: engine)))
        engine.finishMiss()

        XCTAssertFalse(engine.fire(at: cell))
        XCTAssertEqual(engine.attempts, 2)
    }

    func testSinkingTheFleetWinsTheGame() {
        let engine = makeEngine()
        confirmFleets(engine)

        for ship in engine.boards[1].ships {
            for cell in ship.cells {
                XCTAssertTrue(engine.fire(at: cell))
            }
        }
        XCTAssertTrue(engine.isFinished)
        XCTAssertEqual(engine.phase, .finished)
        XCTAssertEqual(engine.winnerProfileIDs, [engine.players[0].profileID])
        XCTAssertEqual(engine.shipsSunk(by: 0), engine.boards[1].ships.count)
        XCTAssertFalse(engine.canFire)
    }

    func testSnapshotRoundTripKeepsTheBattle() {
        let engine = makeEngine()
        confirmFleets(engine)
        let ship = engine.boards[1].ships[0]
        engine.fire(at: ship.cells[0])
        engine.fire(at: emptyCell(in: engine))
        engine.finishMiss()

        let snapshot = engine.snapshot
        XCTAssertTrue(snapshot.isResumable)

        let resumed = GameEngine(snapshot: snapshot, seed: 99)
        XCTAssertEqual(resumed.phase, .playing)
        XCTAssertEqual(resumed.currentPlayerIndex, 1)
        XCTAssertEqual(resumed.attempts, 2)
        XCTAssertEqual(resumed.hitCount(of: 0), 1)
        XCTAssertEqual(resumed.boards, engine.boards)
    }

    func testFinishedSnapshotIsNotResumable() {
        let engine = makeEngine()
        confirmFleets(engine)
        for ship in engine.boards[1].ships {
            for cell in ship.cells {
                engine.fire(at: cell)
            }
        }
        XCTAssertFalse(engine.snapshot.isResumable)
    }

    func testCorruptSnapshotIsNotResumable() {
        let engine = makeEngine()
        confirmFleets(engine)
        var snapshot = engine.snapshot
        // Een boot buiten de rand: dat spel klopt niet meer.
        snapshot.boards[0].ships[0].cells[0] = Coord(row: 99, col: 0)
        XCTAssertFalse(snapshot.isResumable)
    }

    func testRematchProfilesKeepTheOpponent() {
        let engine = makeEngine(mode: .versusComputer)
        let profiles = engine.rematchProfiles()
        XCTAssertEqual(profiles.count, 2)
        XCTAssertEqual(profiles.last?.computerLevel, .medium)
        XCTAssertEqual(profiles.first?.name, "Lene")
    }

    func testStartingPlayerAlternatesInRematch() {
        let engine = makeEngine()
        XCTAssertEqual(engine.startingPlayerIndex, 0)
        let rematch = GameEngine(
            mode: engine.mode,
            profiles: engine.rematchProfiles(),
            boardSize: engine.boardSize,
            startingPlayerIndex: (engine.startingPlayerIndex + 1) % 2,
            seed: 3
        )
        XCTAssertEqual(rematch.startingPlayerIndex, 1)
        XCTAssertEqual(rematch.currentPlayerIndex, 1)
    }
}
