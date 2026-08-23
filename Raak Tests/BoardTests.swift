import XCTest
@testable import Raak

/// Het zeebord: vloot leggen, schieten en zinken.
@MainActor
final class BoardTests: XCTestCase {
    func testFleetPlacementIsValid() {
        // Veel zaadjes, alle maten: de vloot moet altijd compleet, binnen de
        // randen en zonder overlap liggen.
        for size in BoardSize.allCases {
            for seed in UInt64(0)..<40 {
                var rng = SplitMix64(seed: seed)
                let board = size.placeFleet(using: &rng)

                XCTAssertEqual(
                    board.ships.map(\.kind).sorted { $0.rawValue < $1.rawValue },
                    size.fleet.sorted { $0.rawValue < $1.rawValue }
                )
                var seen: Set<Coord> = []
                for ship in board.ships {
                    XCTAssertEqual(ship.cells.count, ship.kind.length)
                    XCTAssertTrue(isStraightLine(ship.cells), "Boot ligt niet in een rechte lijn")
                    for cell in ship.cells {
                        XCTAssertTrue((0..<size.gridSize).contains(cell.row))
                        XCTAssertTrue((0..<size.gridSize).contains(cell.col))
                        XCTAssertTrue(seen.insert(cell).inserted, "Boten overlappen")
                    }
                }
            }
        }
    }

    func testShotsHitMissAndSink() {
        var rng = SplitMix64(seed: 7)
        var board = BoardSize.small.placeFleet(using: &rng)
        let ship = board.ships[0]

        // Een misser: een vakje zonder boot.
        let occupied = Set(board.ships.flatMap(\.cells))
        let empty = (0..<board.gridSize).flatMap { row in
            (0..<board.gridSize).map { Coord(row: row, col: $0) }
        }.first { !occupied.contains($0) }!
        XCTAssertEqual(board.receiveShot(at: empty), .miss)

        // Nog eens op hetzelfde vakje: loze tik, geen beurt kwijt.
        XCTAssertNil(board.receiveShot(at: empty))

        // De boot vakje voor vakje raken; het laatste schot laat hem zinken.
        for (index, cell) in ship.cells.enumerated() {
            let result = board.receiveShot(at: cell)
            if index == ship.cells.count - 1 {
                XCTAssertEqual(result, .sunk(ship.kind))
            } else {
                XCTAssertEqual(result, .hit)
            }
        }
        XCTAssertEqual(board.ships[0].hits.count, ship.kind.length)
        XCTAssertFalse(board.allSunk)
    }

    func testAllSunkEndsTheSea() {
        var rng = SplitMix64(seed: 11)
        var board = BoardSize.small.placeFleet(using: &rng)
        for ship in board.ships {
            for cell in ship.cells {
                _ = board.receiveShot(at: cell)
            }
        }
        XCTAssertTrue(board.allSunk)
        XCTAssertEqual(board.hitCount, board.ships.reduce(0) { $0 + $1.kind.length })
    }

    private func isStraightLine(_ cells: [Coord]) -> Bool {
        guard let first = cells.first else { return false }
        return cells.allSatisfy { $0.row == first.row } || cells.allSatisfy { $0.col == first.col }
    }
}
