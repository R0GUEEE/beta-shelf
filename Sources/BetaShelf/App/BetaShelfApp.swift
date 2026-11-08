import SwiftUI

@main
struct BetaShelfApp: App {
    @StateObject private var store = CatalogStore.shared
    @AppStorage("appearance") private var appearance: String = "system"

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Theme.blue)
                .preferredColorScheme(colorScheme)
                .task {
                    await store.refreshStatuses(limit: 25)
                }
        }
    }

    private var colorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}
