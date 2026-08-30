import SwiftUI

@main
struct RaakApp: App {
    @State private var profileStore = ProfileStore()
    @State private var gameStore = GameStore()
    @State private var entitlements = EntitlementStore()
    @Environment(\.scenePhase) private var scenePhase

    /// DEBUG-hulp voor demo's en screenshots: start de app met
    /// `-demoThema snoep` (of `oceaan`, `nacht`) om een premiumthema te
    /// bekijken zonder aankoop. In releasebuilds bestaat dit luik niet.
    private var demoThema: ThemeID? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-demoThema"),
              arguments.indices.contains(index + 1) else { return nil }
        return ThemeID(rawValue: arguments[index + 1])
        #else
        return nil
        #endif
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(profileStore)
                .environment(gameStore)
                .environment(entitlements)
                .appMetrics()
                .task {
                    if let demoThema {
                        ThemeStore.shared.select(demoThema)
                    }
                    // Bij de start opnieuw toetsen: na een terugbetaling mag
                    // een premiumthema niet blijven hangen.
                    await entitlements.load()
                    if !entitlements.isFamilyUnlocked, demoThema == nil {
                        ThemeStore.shared.enforceFreeTheme()
                    }
                }
                .onChange(of: entitlements.isFamilyUnlocked) { _, unlocked in
                    if !unlocked, demoThema == nil {
                        ThemeStore.shared.enforceFreeTheme()
                    }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            // Naar de achtergrond: eerst de wachtrij met zetten op schijf
            // laten landen, zodat een snelle force-quit niets verliest.
            if phase == .background {
                Task { await gameStore.flush() }
            }
        }
    }
}
