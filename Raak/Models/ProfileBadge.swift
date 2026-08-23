import Foundation

/// Eén trofee in de kast. Elk doel is positief geformuleerd: er valt altijd
/// iets te verzamelen en nooit iets te verliezen — belangrijk in een
/// kinderapp.
struct ProfileBadge: Identifiable, Equatable {
    let id: String
    let title: String
    let goal: String
    let icon: String
    let isEarned: Bool

    /// De hele kast voor één profiel, in vaste volgorde: van makkelijk naar
    /// moeilijk, zodat er snel iets glimt.
    static func collection(for profile: PlayerProfile) -> [ProfileBadge] {
        [
            ProfileBadge(
                id: "eerste-potje",
                title: String(localized: "Eerste potje"),
                goal: String(localized: "Speel je eerste potje"),
                icon: "water.waves",
                isEarned: profile.gamesPlayed >= 1
            ),
            ProfileBadge(
                id: "winnaar",
                title: String(localized: "Winnaar"),
                goal: String(localized: "Win een potje"),
                icon: "crown.fill",
                isEarned: profile.wins >= 1
            ),
            ProfileBadge(
                id: "scherpschutter",
                title: String(localized: "Scherpschutter"),
                goal: String(localized: "Schiet 5 keer raak in één potje"),
                icon: "target",
                isEarned: profile.mostHits >= 5
            ),
            ProfileBadge(
                id: "hattrick",
                title: String(localized: "Hattrick"),
                goal: String(localized: "Win 3 potjes op rij"),
                icon: "sparkles",
                isEarned: profile.bestStreak >= 3
            ),
            ProfileBadge(
                id: "voltreffer",
                title: String(localized: "Voltreffer"),
                goal: String(localized: "Schiet 9 keer raak in één potje"),
                icon: "flame.fill",
                isEarned: profile.mostHits >= 9
            ),
            ProfileBadge(
                id: "speelvogel",
                title: String(localized: "Speelvogel"),
                goal: String(localized: "Speel 10 potjes"),
                icon: "star.fill",
                isEarned: profile.gamesPlayed >= 10
            ),
            ProfileBadge(
                id: "winmachine",
                title: String(localized: "Winmachine"),
                goal: String(localized: "Win 5 potjes"),
                icon: "trophy.fill",
                isEarned: profile.wins >= 5
            ),
            ProfileBadge(
                id: "kanonskoning",
                title: String(localized: "Kanonskoning"),
                goal: String(localized: "Schiet 12 keer raak in één potje"),
                icon: "bolt.fill",
                isEarned: profile.mostHits >= 12
            ),
            ProfileBadge(
                id: "onverslaanbaar",
                title: String(localized: "Onverslaanbaar"),
                goal: String(localized: "Win 5 potjes op rij"),
                icon: "wand.and.stars",
                isEarned: profile.bestStreak >= 5
            ),
            ProfileBadge(
                id: "sterspeler",
                title: String(localized: "Sterspeler"),
                goal: String(localized: "Win 10 potjes"),
                icon: "star.circle.fill",
                isEarned: profile.wins >= 10
            ),
            ProfileBadge(
                id: "kampioen",
                title: String(localized: "Kampioen"),
                goal: String(localized: "Speel 25 potjes"),
                icon: "medal.fill",
                isEarned: profile.gamesPlayed >= 25
            ),
            ProfileBadge(
                id: "zeeslaglegende",
                title: String(localized: "Zeeslaglegende"),
                goal: String(localized: "Speel 50 potjes"),
                icon: "checkmark.seal.fill",
                isEarned: profile.gamesPlayed >= 50
            )
        ]
    }
}
