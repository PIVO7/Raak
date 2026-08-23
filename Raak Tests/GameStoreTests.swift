import XCTest
@testable import Raak

@MainActor
final class GameStoreTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        fileURL = URL.temporaryDirectory.appending(path: "game-test-\(UUID()).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL)
        super.tearDown()
    }

    private func makeEngine(seed: UInt64 = 7) -> GameEngine {
        let engine = GameEngine(
            mode: .versusFriends,
            profiles: [
                PlayerProfile(name: "Lene"),
                PlayerProfile(name: "Ellis", avatarColorIndex: 1)
            ],
            boardSize: .small,
            seed: seed
        )
        while engine.arrangingPlayerIndex != nil {
            engine.confirmFleet()
        }
        return engine
    }

    /// Laat de speler aan zet één keer missen en geeft de beurt door, zodat
    /// elke aanroep de stand echt verandert.
    private func missOnce(in engine: GameEngine) {
        let board = engine.boards[engine.opponentIndex]
        let occupied = Set(board.ships.flatMap(\.cells))
        let empty = (0..<board.gridSize).flatMap { row in
            (0..<board.gridSize).map { Coord(row: row, col: $0) }
        }.first { !occupied.contains($0) && !board.shots.contains($0) }!
        engine.fire(at: empty)
        engine.finishMiss()
    }

    func testSaveAndReload() async {
        let engine = makeEngine()
        missOnce(in: engine)
        let store = GameStore(fileURL: fileURL)
        store.save(engine.snapshot)
        await store.flush()

        let reloaded = GameStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.savedGame?.shotsFired, [1, 0])
        XCTAssertEqual(reloaded.savedGame?.summaryTitle, "Lene · Ellis")
        XCTAssertEqual(reloaded.savedGame?.currentPlayerIndex, 1)
    }

    func testClearRemovesFile() async {
        let store = GameStore(fileURL: fileURL)
        store.save(makeEngine().snapshot)
        await store.flush()
        store.clear()
        await store.flush()

        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertNil(GameStore(fileURL: fileURL).savedGame)
    }

    func testFinishedGameIsNotResumed() async {
        let engine = makeEngine()
        for ship in engine.boards[1].ships {
            for cell in ship.cells {
                engine.fire(at: cell)
            }
        }
        XCTAssertTrue(engine.isFinished)
        let store = GameStore(fileURL: fileURL)
        store.save(engine.snapshot)
        await store.flush()

        XCTAssertNil(GameStore(fileURL: fileURL).savedGame)
    }

    func testCorruptBoardIsNotResumed() async {
        var snapshot = makeEngine().snapshot
        // Een boot buiten de rand: dat spel klopt niet meer.
        snapshot.boards[0].ships[0].cells[0] = Coord(row: 99, col: 99)
        let store = GameStore(fileURL: fileURL)
        store.save(snapshot)
        await store.flush()

        XCTAssertNil(GameStore(fileURL: fileURL).savedGame)
    }

    func testLatestWriteWins() async {
        let engine = makeEngine()
        let store = GameStore(fileURL: fileURL)
        store.save(engine.snapshot)
        missOnce(in: engine)
        store.save(engine.snapshot)
        missOnce(in: engine)
        store.save(engine.snapshot)
        await store.flush()

        XCTAssertEqual(GameStore(fileURL: fileURL).savedGame?.shotsFired, [1, 1])
    }

    func testPlacementPhaseIsResumable() async {
        // Ook halverwege het vloot leggen mag een spel terugkomen.
        let engine = GameEngine(
            mode: .versusFriends,
            profiles: [
                PlayerProfile(name: "Lene"),
                PlayerProfile(name: "Ellis", avatarColorIndex: 1)
            ],
            boardSize: .small,
            seed: 7
        )
        engine.confirmFleet()
        let store = GameStore(fileURL: fileURL)
        store.save(engine.snapshot)
        await store.flush()

        let resumed = GameStore(fileURL: fileURL).savedGame
        XCTAssertEqual(resumed?.phase, .placement)
        XCTAssertEqual(resumed?.placementReady, [true, false])
    }
}
