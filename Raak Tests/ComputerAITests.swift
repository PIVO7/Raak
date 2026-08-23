import XCTest
@testable import Raak

/// De computerschutter: eerlijk (hij kent de vloot niet) maar wel slim
/// genoeg om een aangeschoten boot af te maken.
@MainActor
final class ComputerAITests: XCTestCase {
    func testNeverShootsTheSameCellTwice() {
        let ai = ComputerAI()
        var rng = SplitMix64(seed: 5)
        var shots: Set<Coord> = []
        for _ in 0..<36 {
            guard let shot = ai.chooseShot(gridSize: 6, shots: shots, level: .easy, using: &rng) else {
                return XCTFail("Zee nog niet vol maar geen schot meer")
            }
            XCTAssertTrue(shots.insert(shot).inserted, "Zelfde vakje twee keer beschoten")
        }
        // De zee is vol: nu is er echt niets meer te kiezen.
        XCTAssertNil(ai.chooseShot(gridSize: 6, shots: shots, level: .easy, using: &rng))
    }

    func testHardFollowsUpOnAHit() {
        let ai = ComputerAI()
        var rng = SplitMix64(seed: 9)
        let hit = Coord(row: 3, col: 3)
        var shots: Set<Coord> = [hit]
        ai.note(result: .hit, at: hit, level: .hard, using: &rng)

        let next = ai.chooseShot(gridSize: 8, shots: shots, level: .hard, using: &rng)!
        let distance = abs(next.row - hit.row) + abs(next.col - hit.col)
        XCTAssertEqual(distance, 1, "De professor hoort naast de treffer te mikken")

        // Tweede treffer op een lijn: daarna mikt hij op de uiteinden.
        shots.insert(next)
        ai.note(result: .hit, at: next, level: .hard, using: &rng)
        let third = ai.chooseShot(gridSize: 8, shots: shots, level: .hard, using: &rng)!
        let sameRow = hit.row == next.row && third.row == hit.row
        let sameCol = hit.col == next.col && third.col == hit.col
        XCTAssertTrue(sameRow || sameCol, "Na twee treffers op een lijn hoort het derde schot op die lijn")
    }

    func testSunkResetsTheHunt() {
        let ai = ComputerAI()
        var rng = SplitMix64(seed: 2)
        let hit = Coord(row: 0, col: 0)
        ai.note(result: .hit, at: hit, level: .hard, using: &rng)
        ai.note(result: .sunk(.sloep), at: Coord(row: 0, col: 1), level: .hard, using: &rng)

        // Zonder openstaande jacht jaagt de professor weer in dambord.
        let shots: Set<Coord> = [hit, Coord(row: 0, col: 1)]
        for _ in 0..<10 {
            let shot = ai.chooseShot(gridSize: 8, shots: shots, level: .hard, using: &rng)!
            XCTAssertTrue((shot.row + shot.col).isMultiple(of: 2), "Dambordpatroon verwacht")
        }
    }

    func testHardAlwaysSinksTheFleet() {
        // Een volledige solo-jacht: de professor moet elke vloot vinden
        // binnen het aantal vakjes van de zee.
        var rng = SplitMix64(seed: 4)
        var board = BoardSize.medium.placeFleet(using: &rng)
        let ai = ComputerAI()

        var shotsTaken = 0
        while !board.allSunk {
            guard let shot = ai.chooseShot(gridSize: board.gridSize, shots: board.shots, level: .hard, using: &rng),
                  let result = board.receiveShot(at: shot) else {
                return XCTFail("De jacht liep vast")
            }
            ai.note(result: result, at: shot, level: .hard, using: &rng)
            shotsTaken += 1
            XCTAssertLessThanOrEqual(shotsTaken, board.gridSize * board.gridSize)
        }
        XCTAssertTrue(board.allSunk)
    }

    func testRelearnResumesTheHunt() {
        // Na een hervatting: één treffer op een nog varende boot; de AI
        // hoort meteen weer naast die treffer te mikken.
        var rng = SplitMix64(seed: 6)
        var board = BoardSize.small.placeFleet(using: &rng)
        let ship = board.ships.first { $0.kind.length >= 3 }!
        _ = board.receiveShot(at: ship.cells[0])

        let ai = ComputerAI()
        ai.relearn(board: board)
        let next = ai.chooseShot(gridSize: board.gridSize, shots: board.shots, level: .hard, using: &rng)!
        let distance = abs(next.row - ship.cells[0].row) + abs(next.col - ship.cells[0].col)
        XCTAssertEqual(distance, 1)
    }
}
