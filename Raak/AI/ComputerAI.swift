import Foundation

/// De computerschutter met een menselijk vizier: hij weet alleen wat zijn
/// eigen schoten hem leerden — gluren onder water kan hij niet. Na een
/// treffer zoekt hij de buurvakjes af, zoals een kind dat ook doet; hoe
/// slimmer het persona, hoe beter hij dat volhoudt.
@MainActor
final class ComputerAI {
    /// Vakjes die hij nog wil proberen omdat er vlakbij iets raak was.
    private var pendingTargets: [Coord] = []
    /// De rake schoten op de boot die hij nu aan het zoeken is.
    private var streakHits: [Coord] = []

    /// Kiest het volgende doelwit. `shots` zijn alle vakjes die al beschoten
    /// zijn op de zee van de tegenstander.
    func chooseShot(
        gridSize: Int,
        shots: Set<Coord>,
        level: ComputerLevel,
        using rng: inout SplitMix64
    ) -> Coord? {
        pendingTargets.removeAll { shots.contains($0) || !inBounds($0, gridSize: gridSize) }

        // Doorzoeken bij een aangeschoten boot — maar Dommel vergeet dat
        // nogal eens en schiet dan toch weer zomaar ergens.
        if !pendingTargets.isEmpty, Double.random(in: 0..<1, using: &rng) < level.followUpChance {
            return pendingTargets.removeFirst()
        }

        let open = (0..<gridSize).flatMap { row in
            (0..<gridSize).compactMap { col in
                let coord = Coord(row: row, col: col)
                return shots.contains(coord) ? nil : coord
            }
        }
        guard !open.isEmpty else { return nil }

        // De professor jaagt in dambordpatroon: elke boot is minstens twee
        // vakjes lang, dus de helft van de zee volstaat om alles te vinden.
        if level.huntsWithParity {
            let parity = open.filter { ($0.row + $0.col).isMultiple(of: 2) }
            if let pick = parity.randomElement(using: &rng) {
                return pick
            }
        }
        return open.randomElement(using: &rng)
    }

    /// Leert van het eigen schot dat net viel.
    func note(result: ShotResult, at coord: Coord, level: ComputerLevel, using rng: inout SplitMix64) {
        switch result {
        case .miss:
            break
        case .hit:
            streakHits.append(coord)
            requeueTargets(level: level, using: &rng)
        case .sunk:
            // De boot is gevonden; het zoeken eromheen kan stoppen. Omdat
            // boten met een vakje water ertussen liggen, raakt er zo geen
            // andere treffer zoek.
            streakHits = []
            pendingTargets = []
        }
    }

    /// Na een hervatting kent hij zijn vizier niet meer; hij leest zijn
    /// rake-maar-nog-niet-gezonken schoten terug uit het bord.
    func relearn(board: PlayerBoard) {
        streakHits = board.ships
            .filter { !$0.isSunk }
            .flatMap { ship in ship.cells.filter { ship.hits.contains($0) } }
        var rng = SplitMix64(seed: 0)
        requeueTargets(level: .hard, using: &rng)
    }

    // MARK: - Privé

    /// Bouwt de lijst met kandidaat-vakjes rond de rake schoten opnieuw op.
    /// Bij twee of meer treffers op een lijn mikken de slimme persona's
    /// eerst op de uiteinden van die lijn.
    private func requeueTargets(level: ComputerLevel, using rng: inout SplitMix64) {
        pendingTargets = []
        guard let first = streakHits.first else { return }

        if streakHits.count >= 2, level.extendsLines {
            let horizontal = streakHits.allSatisfy { $0.row == first.row }
            let vertical = streakHits.allSatisfy { $0.col == first.col }
            if horizontal {
                let cols = streakHits.map(\.col)
                pendingTargets = [
                    Coord(row: first.row, col: (cols.min() ?? 0) - 1),
                    Coord(row: first.row, col: (cols.max() ?? 0) + 1)
                ].shuffled(using: &rng)
                return
            }
            if vertical {
                let rows = streakHits.map(\.row)
                pendingTargets = [
                    Coord(row: (rows.min() ?? 0) - 1, col: first.col),
                    Coord(row: (rows.max() ?? 0) + 1, col: first.col)
                ].shuffled(using: &rng)
                return
            }
        }

        pendingTargets = streakHits
            .flatMap { hit in
                [
                    Coord(row: hit.row - 1, col: hit.col),
                    Coord(row: hit.row + 1, col: hit.col),
                    Coord(row: hit.row, col: hit.col - 1),
                    Coord(row: hit.row, col: hit.col + 1)
                ]
            }
            .shuffled(using: &rng)
    }

    private func inBounds(_ coord: Coord, gridSize: Int) -> Bool {
        (0..<gridSize).contains(coord.row) && (0..<gridSize).contains(coord.col)
    }
}

extension ComputerLevel {
    /// Kans dat hij na een treffer echt blijft doorzoeken in plaats van
    /// weer zomaar te schieten.
    var followUpChance: Double {
        switch self {
        case .easy: return 0.45
        case .medium: return 0.9
        case .hard: return 1.0
        }
    }

    /// Mikken op de uiteinden van een rij treffers.
    var extendsLines: Bool {
        self != .easy
    }

    /// Jagen in dambordpatroon; alleen de professor is zo systematisch.
    var huntsWithParity: Bool {
        self == .hard
    }
}
