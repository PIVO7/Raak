import Foundation

/// Eén afgerond potje in de geschiedenis van een profiel: genoeg voor het
/// grafiekje en de trofeeën, niet meer dan dat.
struct GameRecord: Codable, Equatable, Hashable {
    /// Aantal rake schoten in dit potje.
    var hits: Int
    var won: Bool
    var draw: Bool
    var date: Date
}
