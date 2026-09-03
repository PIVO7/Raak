import Foundation

/// De spelvorm. Klassiek schiet je één keer en mag je bij een treffer nog
/// eens; bij Salvo krijg je per beurt zoveel schoten als je nog boten hebt.
/// Dat draait het spel om: wie voorstaat schiet lange salvo's, wie boten
/// verliest schiet er steeds minder — en mikken loont, want doorrammen op een
/// treffer kan niet meer.
enum GameVariant: String, CaseIterable, Identifiable, Codable {
    case classic
    case salvo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: String(localized: "Klassiek")
        case .salvo: String(localized: "Salvo")
        }
    }

    var subtitle: String {
        switch self {
        case .classic: String(localized: "Raak? Nog een schot")
        case .salvo: String(localized: "Zoveel schoten als je boten hebt")
        }
    }

    var symbol: String {
        switch self {
        case .classic: "scope"
        case .salvo: "burst.fill"
        }
    }

    /// Alleen de klassieke spelvorm is gratis; de rest hoort bij de
    /// Gezinsversie.
    var isPremium: Bool { self != .classic }
}
