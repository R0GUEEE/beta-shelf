import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var store: CatalogStore

    @State private var query = ""
    @State private var storeResults: [StoreApp] = []
    @State private var isSearching = false
    @State private var errorText: String? = nil
    @State private var storeSelection: StoreApp? = nil
    @State private var showAdd = false

    private var local: [BetaApp] { store.search(query) }

    private let suggestions = ["Games", "Developer Tools", "Music", "Photography", "AI", "Widgets",
                               "Productivity", "Finance", "Emulators"]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    if query.isEmpty {
                        suggestionsBlock
                        categoriesBlock
                    } else {
                        localBlock
                        storeBlock
                    }
                }
                .padding(.vertical, 10)
                .padding(.bottom, 40)
            }
            .navigationTitle("Search")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Apps, developers, categories")
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .navigationDestination(for: BetaApp.self) { app in
                BetaDetailView(app: app)
            }
            .sheet(item: $storeSelection) { item in
                StoreAppSheet(app: item)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAdd) { AddBetaSheet() }
            .task(id: query) { await runSearch() }
        }
    }

    // MARK: Empty state

    private var suggestionsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try a category")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .padding(.horizontal, 20)
            FlowChips(items: suggestions) { item in
                query = item
            }
            .padding(.horizontal, 20)
        }
    }

    private var categoriesBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Browse categories", subtitle: "\(store.openBetas.count) public betas indexed")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                      spacing: 12) {
                ForEach(store.genres.prefix(12)) { item in
                    Button {
                        query = item.name
                    } label: {
                        ZStack(alignment: .bottomLeading) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Theme.gradient(for: item.name))
                                .frame(height: 78)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.name)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                Text("\(item.count) betas")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(12)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            Button {
                showAdd = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "link.badge.plus")
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Add a TestFlight link")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Paste any public invite and we'll index it")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .card(radius: 16, material: .thinMaterial)
            }
            .buttonStyle(.plain)
            .foregroundColor(.primary)
            .padding(.horizontal, 20)
        }
    }

    // MARK: Results

    @ViewBuilder
    private var localBlock: some View {
        if !local.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Public betas", subtitle: "\(local.count) matches in Beta Shelf")
                VStack(spacing: 0) {
                    ForEach(local.prefix(20)) { app in
                        NavigationLink(value: app) {
                            AppRow(app: app)
                                .padding(.horizontal, 20)
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 90)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var storeBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionHeader(title: "On the App Store", subtitle: "Check whether a public beta exists")
                if isSearching { ProgressView().controlSize(.small).padding(.trailing, 20) }
            }
            if let errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
            }
            VStack(spacing: 0) {
                ForEach(storeResults.prefix(12)) { item in
                    let beta = store.hasBeta(forTrackId: item.trackId)
                    if let beta {
                        NavigationLink(value: beta) {
                            StoreRow(item: item, beta: beta)
                                .padding(.horizontal, 20)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            storeSelection = item
                        } label: {
                            StoreRow(item: item, beta: nil)
                                .padding(.horizontal, 20)
                        }
                        .buttonStyle(.plain)
                    }
                    Divider().padding(.leading, 90)
                }
            }
            if storeResults.isEmpty && !isSearching && errorText == nil {
                Text("No App Store results. Try a different spelling.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
        }
    }

    private func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            storeResults = []
            errorText = nil
            return
        }
        isSearching = true
        errorText = nil
        do {
            try await Task.sleep(nanoseconds: 350_000_000)
            let results = try await AppStoreClient.search(term: trimmed, limit: 25)
            guard !Task.isCancelled else { return }
            storeResults = results
        } catch {
            guard !Task.isCancelled else { return }
            storeResults = []
            errorText = "App Store lookup failed: \(error.localizedDescription)"
        }
        isSearching = false
    }
}

// MARK: - Rows

struct StoreRow: View {
    let item: StoreApp
    let beta: BetaApp?

    var body: some View {
        HStack(spacing: 12) {
            AppIconView(url: item.icon, size: 58)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.trackName)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text(item.developer)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    StarsView(rating: item.averageUserRating ?? 0, size: 8)
                    Text(String(format: "%.1f", item.averageUserRating ?? 0))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    if let beta {
                        StatusBadge(status: beta.status)
                    }
                }
            }
            Spacer(minLength: 6)
            if beta != nil {
                JoinPill()
            } else {
                Text("NO BETA")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(0.4)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

struct FlowChips: View {
    let items: [String]
    let onTap: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button {
                    onTap(item)
                } label: {
                    Text(item)
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .padding(.horizontal, 6)
                        .foregroundColor(.primary)
                        .background(Color(uiColor: .secondarySystemBackground),
                                    in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Store app sheet

struct StoreAppSheet: View {
    let app: StoreApp
    @Environment(\.dismiss) private var dismiss
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 14) {
                        AppIconView(url: app.icon, size: 76)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(app.trackName)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            Text(app.developer)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text(app.sub)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(Theme.orange)
                        Text("No public beta is indexed for this app yet.")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Theme.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if let description = app.description {
                        Text(description)
                            .font(.system(size: 13))
                            .lineSpacing(2)
                            .foregroundColor(.secondary)
                            .lineLimit(6)
                    }

                    Button {
                        showAdd = true
                    } label: {
                        Label("Add its TestFlight link", systemImage: "link.badge.plus")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundColor(.white)
                            .background(Theme.blue, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if let urlString = app.trackViewUrl, let url = URL(string: urlString) {
                        Link(destination: url) {
                            Label("View on the App Store", systemImage: "arrow.up.right.square")
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("App Store app")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddBetaSheet(prefillName: app.trackName)
            }
        }
    }
}

#Preview {
    SearchView().environmentObject(CatalogStore.shared)
}
