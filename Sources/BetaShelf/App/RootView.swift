import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: CatalogStore
    @State private var tab: Int = 0

    var body: some View {
        TabView(selection: $tab) {
            BrowseView()
                .tabItem { Label("Discover", systemImage: "square.grid.2x2.fill") }
                .tag(0)

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(1)

            MyBetasView()
                .tabItem { Label("My Betas", systemImage: "square.stack.3d.up.fill") }
                .tag(2)
        }
    }
}

#Preview {
    RootView().environmentObject(CatalogStore.shared)
}
