import XCTest
@testable import Raak

/// De spelvorm Salvo: per beurt zoveel schoten als je nog boten hebt, of je
/// nu raak schiet of niet.
@MainActor
final class GameVariantTests: XCTestCase {
    private func makeEngine(
        variant: GameVariant,
        boardSize: BoardSize = .small,
        seed: UInt64 = 7
    ) -> GameEngine {
        let engine = GameEngine(
            mode: .versusFriends,
            variant: variant,
            profiles: [
                PlayerProfile(name: "Lene"),
                PlayerProfile(name: "Ellis", avatarColorIndex: 1)
            ],
            boardSize: boardSize,
            seed: seed
        )
        while engine.arrangingPlayerIndex != nil {
            engine.confirmFleet()
        }
        return engine
    }

    /// Een leeg vakje op de zee van de tegenstander van de speler aan zet.
    private func emptyCell(in engine: GameEngine) -> Coord {
        let board = engine.boards[engine.opponentIndex]
        let occupied = Set(board.ships.flatMap(\.cells))
        return (0..<board.gridSize).flatMap { row in
            (0..<board.gridSize).map { Coord(row: row, col: $0) }
        }.first { !occupied.contains($0) && !board.shots.contains($0) }!
    }

    func testSalvoStartsWithOneShotPerShip() {
        let engine = makeEngine(variant: .salvo)

        XCTAssertEqual(engine.shotsRemaining, engine.boards[0].ships.count)
        XCTAssertTrue(engine.turnMessage.contains("\(engine.boards[0].ships.count)"))
    }

    func testSalvoKeepsTheTurnUntilTheVolleyIsSpent() {
        let engine = makeEngine(variant: .salvo)
        let salvo = engine.shotsRemaining
        XCTAssertGreaterThan(salvo, 1)

        for shot in 1..<salvo {
            XCTAssertTrue(engine.fire(at: emptyCell(in: engine)))
            // Elke plons blijft even staan, maar de beurt blijft van speler 1.
            XCTAssertTrue(engine.isResolving)
            engine.finishMiss()
            XCTAssertEqual(engine.currentPlayerIndex, 0)
            XCTAssertEqual(engine.shotsRemaining, salvo - shot)
        }

        XCTAssertTrue(engine.fire(at: emptyCell(in: engine)))
        engine.finishMiss()
        XCTAssertEqual(engine.currentPlayerIndex, 1)
        XCTAssertEqual(engine.attempts, salvo)
        // De ander begint aan een eigen, even lang salvo.
        XCTAssertEqual(engine.shotsRemaining, engine.boards[1].ships.count)
    }

    /// Het echte verschil met klassiek: raak schieten levert geen extra
    /// schot op.
    func testSalvoHitDoesNotGrantAnExtraShot() {
        let engine = makeEngine(variant: .salvo)
        let salvo = engine.shotsRemaining
        let target = engine.boards[1].ships.first { $0.kind.length > salvo }!

        for shot in 0..<salvo {
            XCTAssertTrue(engine.fire(at: target.cells[shot]))
            XCTAssertEqual(engine.currentPlayerIndex, 0)
        }
        // De boot vaart nog, maar het salvo is op.
        XCTAssertFalse(engine.boards[1].ships.first { $0.id == target.id }!.isSunk)
        XCTAssertTrue(engine.isResolving)

        engine.finishMiss()
        XCTAssertEqual(engine.currentPlayerIndex, 1)
    }

    func testSalvoShrinksWhenYourOwnShipSinks() {
        let engine = makeEngine(variant: .salvo)
        let salvo = engine.shotsRemaining

        // Speler 1 schiet zijn salvo in het water.
        for _ in 0..<salvo {
            XCTAssertTrue(engine.fire(at: emptyCell(in: engine)))
            engine.finishMiss()
        }
        XCTAssertEqual(engine.currentPlayerIndex, 1)

        // Speler 2 boort de kleinste boot van speler 1 de grond in en schiet
        // de rest van zijn salvo in het water.
        let victim = engine.boards[0].ships.min { $0.kind.length < $1.kind.length }!
        var used = 0
        for cell in victim.cells {
            XCTAssertTrue(engine.fire(at: cell))
            used += 1
        }
        while engine.shotsRemaining > 0 {
            XCTAssertTrue(engine.fire(at: emptyCell(in: engine)))
            used += 1
        }
        XCTAssertEqual(used, salvo)
        engine.finishMiss()

        // Terug bij speler 1: een boot minder, dus een schot minder.
        XCTAssertEqual(engine.currentPlayerIndex, 0)
        XCTAssertTrue(engine.boards[0].ships.first { $0.id == victim.id }!.isSunk)
        XCTAssertEqual(engine.shotsRemaining, salvo - 1)
    }

    /// Klassiek blijft klassiek: raak is nog een schot, en het salvo telt niet
    /// mee.
    func testClassicKeepsShootingAfterAHit() {
        let engine = makeEngine(variant: .classic)
        let target = engine.boards[1].ships.first { $0.kind.length >= 3 }!

        XCTAssertEqual(engine.shotsRemaining, 1)
        XCTAssertTrue(engine.fire(at: target.cells[0]))
        XCTAssertFalse(engine.isResolving)
        XCTAssertEqual(engine.currentPlayerIndex, 0)
        XCTAssertTrue(engine.canFire)
        XCTAssertEqual(engine.shotsRemaining, 1)
    }

    /// Bewaarde spellen van vóór de spelvormen laden als klassiek.
    func testSnapshotWithoutVariantIsClassic() {
        let engine = makeEngine(variant: .classic)
        var snapshot = engine.snapshot
        snapshot.variant = nil
        snapshot.shotsRemaining = nil

        let resumed = GameEngine(snapshot: snapshot)
        XCTAssertEqual(resumed.variant, .classic)
        XCTAssertEqual(resumed.shotsRemaining, 1)
    }

    func testSnapshotRoundTripKeepsTheSalvo() throws {
        let engine = makeEngine(variant: .salvo)
        XCTAssertTrue(engine.fire(at: emptyCell(in: engine)))
        engine.finishMiss()
        let halfway = engine.shotsRemaining

        let data = try JSONEncoder().encode(engine.snapshot)
        let decoded = try JSONDecoder().decode(GameSnapshot.self, from: data)
        let resumed = GameEngine(snapshot: decoded)

        XCTAssertEqual(decoded.variant, .salvo)
        XCTAssertEqual(resumed.variant, .salvo)
        // Een half geschoten salvo loopt door waar het gebleven was.
        XCTAssertEqual(resumed.shotsRemaining, halfway)
        XCTAssertTrue(decoded.summaryTitle.contains(GameVariant.salvo.title))
    }
}
