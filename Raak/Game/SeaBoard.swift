import Foundation

/// Eén vakje op zee, rij en kolom vanaf nul. Uitspreekbaar voor VoiceOver
/// als "rij 3, kolom 5".
struct Coord: Codable, Equatable, Hashable {
    var row: Int
    var col: Int
}

/// De boten van de vloot. Elke lengte heeft een eigen naam en kleur, zodat
/// een kind "de Zeilboot is gezonken!" hoort in plaats van "schip van 3".
enum ShipKind: String, Codable, CaseIterable, Identifiable {
    case sloep
    case zeilboot
    case vissersboot
    case stoomboot
    case kapiteinsschip

    var id: String { rawValue }

    var length: Int {
        switch self {
        case .sloep: return 2
        case .zeilboot: return 3
        case .vissersboot: return 3
        case .stoomboot: return 4
        case .kapiteinsschip: return 5
        }
    }

    var title: String {
        switch self {
        case .sloep: return String(localized: "Sloep")
        case .zeilboot: return String(localized: "Zeilboot")
        case .vissersboot: return String(localized: "Vissersboot")
        case .stoomboot: return String(localized: "Stoomboot")
        case .kapiteinsschip: return String(localized: "Kapiteinsschip")
        }
    }

    /// Index in `AvatarBadge.palette`, dezelfde kleuren als de bolletjes.
    var colorIndex: Int {
        switch self {
        case .sloep: return 3
        case .zeilboot: return 2
        case .vissersboot: return 4
        case .stoomboot: return 5
        case .kapiteinsschip: return 0
        }
    }
}

/// Eén boot op het bord: zijn soort, de vakjes die hij bezet en waar hij
/// al geraakt is.
struct Ship: Codable, Equatable, Identifiable {
    var kind: ShipKind
    var cells: [Coord]
    var hits: Set<Coord> = []

    var id: String { kind.rawValue }
    var isSunk: Bool { hits.count == cells.count }
}

/// Wat een schot opleverde; de UI hangt er geluid, tekst en feest aan.
enum ShotResult: Equatable {
    case miss
    case hit
    case sunk(ShipKind)
}

/// De zee van één speler: zijn vloot en alle schoten die de ander erop
/// heeft gelost.
struct PlayerBoard: Codable, Equatable {
    var gridSize: Int
    var ships: [Ship]
    /// Alle vakjes waarop al geschoten is, raak of mis.
    var shots: Set<Coord> = []

    var allSunk: Bool { !ships.isEmpty && ships.allSatisfy(\.isSunk) }

    /// Aantal rake schoten op deze zee — de treffers van de tegenstander.
    var hitCount: Int { ships.reduce(0) { $0 + $1.hits.count } }

    var shipsAfloat: Int { ships.count(where: { !$0.isSunk }) }

    func ship(at coord: Coord) -> Ship? {
        ships.first { $0.cells.contains(coord) }
    }

    func isShot(_ coord: Coord) -> Bool { shots.contains(coord) }

    /// Verwerkt een schot en meldt wat het opleverde. Een vakje dat al
    /// beschoten was, geeft `nil`: geen beurt kwijt aan een loze tik.
    mutating func receiveShot(at coord: Coord) -> ShotResult? {
        guard (0..<gridSize).contains(coord.row), (0..<gridSize).contains(coord.col),
              !shots.contains(coord) else { return nil }
        shots.insert(coord)
        guard let index = ships.firstIndex(where: { $0.cells.contains(coord) }) else {
            return .miss
        }
        ships[index].hits.insert(coord)
        return ships[index].isSunk ? .sunk(ships[index].kind) : .hit
    }
}

/// De drie zeeën. Klein is voor de jongsten; groot is het bord van de
/// grote doos.
enum BoardSize: String, Codable, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var gridSize: Int {
        switch self {
        case .small: return 6
        case .medium: return 8
        case .large: return 10
        }
    }

    /// De vloot die op deze zee vaart.
    var fleet: [ShipKind] {
        switch self {
        case .small: return [.sloep, .zeilboot, .stoomboot]
        case .medium: return [.sloep, .zeilboot, .vissersboot, .stoomboot]
        case .large: return [.sloep, .zeilboot, .vissersboot, .stoomboot, .kapiteinsschip]
        }
    }

    var title: String {
        switch self {
        case .small: return String(localized: "Klein")
        case .medium: return String(localized: "Middel")
        case .large: return String(localized: "Groot")
        }
    }

    var subtitle: String {
        String(localized: "\(gridSize)×\(gridSize) · \(fleet.count) boten")
    }

    /// Legt de vloot willekeurig op zee. Boten raken elkaar niet: met een
    /// vakje water ertussen blijft het bord leesbaar voor een kind. Lukt
    /// dat na veel proberen niet (kan bij pech op het kleine bord), dan
    /// mogen ze alsnog tegen elkaar aan.
    func placeFleet(using rng: inout SplitMix64) -> PlayerBoard {
        for allowTouching in [false, true] {
            attempt: for _ in 0..<200 {
                var ships: [Ship] = []
                var blocked: Set<Coord> = []
                var occupied: Set<Coord> = []
                for kind in fleet {
                    guard let cells = Self.randomSpot(
                        length: kind.length,
                        gridSize: gridSize,
                        avoiding: allowTouching ? occupied : blocked,
                        using: &rng
                    ) else { continue attempt }
                    ships.append(Ship(kind: kind, cells: cells))
                    for cell in cells {
                        occupied.insert(cell)
                        for dr in -1...1 {
                            for dc in -1...1 {
                                blocked.insert(Coord(row: cell.row + dr, col: cell.col + dc))
                            }
                        }
                    }
                }
                return PlayerBoard(gridSize: gridSize, ships: ships)
            }
        }
        // Onbereikbaar met de vlootgroottes hierboven, maar de compiler wil
        // een uitweg: dan maar een lege zee in plaats van een crash.
        return PlayerBoard(gridSize: gridSize, ships: [])
    }

    /// Zoekt één willekeurige vrije plek voor een boot van deze lengte.
    private static func randomSpot(
        length: Int,
        gridSize: Int,
        avoiding blocked: Set<Coord>,
        using rng: inout SplitMix64
    ) -> [Coord]? {
        for _ in 0..<80 {
            let horizontal = Bool.random(using: &rng)
            let row = Int.random(in: 0..<(horizontal ? gridSize : gridSize - length + 1), using: &rng)
            let col = Int.random(in: 0..<(horizontal ? gridSize - length + 1 : gridSize), using: &rng)
            let cells = (0..<length).map {
                Coord(row: row + (horizontal ? 0 : $0), col: col + (horizontal ? $0 : 0))
            }
            if cells.allSatisfy({ !blocked.contains($0) }) {
                return cells
            }
        }
        return nil
    }
}
