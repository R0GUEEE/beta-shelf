import SwiftUI

struct BrowseView: View {
    @EnvironmentObject private var store: CatalogStore
    @State private var showSettings = false
    @State private var showAdd = false
    @State private var filterGenre: String? = nil
    @State private var query = ""

    private var chips: [String] {
        ["All"] + store.genres.prefix(10).map { $0.name }
    }

    private var visibleApps: [BetaApp] {
        let base = query.isEmpty ? store.openBetas : store.search(query)
        guard let genre = filterGenre else { return base }
        return base.filter { $0.genre == genre }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    header
                    if filterGenre == nil && query.isEmpty {
                        featuredCarousel
                    }
                    genreChips
                    if filterGenre == nil && query.isEmpty {
                        newAndNoteworthy
                        ForEach(shelfGenres, id: \.self) { genre in
                            genreShelf(genre)
                        }
                    }
                    catalogueSection
                    footer
                }
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationBarHidden(true)
            .navigationDestination(for: BetaApp.self) { app in
                BetaDetailView(app: app)
            }
            .refreshable {
                await store.refreshStatuses(force: true, limit: 30)
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showAdd) { AddBetaSheet() }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dateStamp)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(1.2)
                    Text("Beta Shelf")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                }
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 27, weight: .regular))
                        .foregroundColor(.primary)
                }
            }

            HStack(spacing: 8) {
                Label("\(store.openBetas.count) public betas", systemImage: "flask.fill")
                Text("·")
                Text(store.isRefreshing
                     ? "checking availability…"
                     : "updated \(lastUpdatedText)")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.secondary)

            HStack(spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14, weight: .semibold))
                    TextField("Filter betas", text: $query)
                        .font(.system(size: 15))
                        .submitLabel(.search)
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color(uiColor: .secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button {
                    showAdd = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                        Text("Add link")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .foregroundColor(.white)
                    .background(Theme.brandGradient, in: Capsule())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var dateStamp: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }

    private var lastUpdatedText: String {
        guard let date = store.lastRefresh ?? store.allApps.compactMap({ $0.lastChecked }).max() else {
            return "just now"
        }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }

    // MARK: Featured

    private var featuredCarousel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Featured", subtitle: "Hand-picked betas worth a look")
            if store.featured.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 60)
            } else {
                TabView {
                    ForEach(store.featured) { app in
                        NavigationLink(value: app) {
                            FeaturedCard(app: app)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 392)
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: Chips

    private var genreChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips, id: \.self) { chip in
                    let active = (chip == "All" && filterGenre == nil) || chip == filterGenre
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if chip == "All" {
                                filterGenre = nil
                            } else {
                                filterGenre = (filterGenre == chip) ? nil : chip
                            }
                        }
                    } label: {
                        Text(chip)
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundColor(active ? .white : .primary)
                            .background {
                                if active {
                                    Capsule().fill(Theme.blue)
                                } else {
                                    Capsule().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                                        .background(Capsule().fill(Color(uiColor: .secondarySystemBackground).opacity(0.6)))
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: Shelves

    private var newAndNoteworthy: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "New & Noteworthy", subtitle: "Freshly added public links")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(store.newAndNoteworthy.prefix(10)) { app in
                        NavigationLink(value: app) {
                            AppTile(app: app)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 2)
            }
        }
    }

    private var shelfGenres: [String] {
        store.genres.filter { $0.count >= 4 }.prefix(5).map { $0.name }
    }

    private func genreShelf(_ genre: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: genre, subtitle: "\(store.apps(in: genre).count) betas", action: {
                withAnimation { filterGenre = genre }
            })
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(store.apps(in: genre).prefix(12)) { app in
                        NavigationLink(value: app) {
                            AppTile(app: app)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: Catalogue list

    private var catalogueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: filterGenre ?? (query.isEmpty ? "All public betas" : "Results"),
                          subtitle: "\(visibleApps.count) apps")
            VStack(spacing: 0) {
                ForEach(visibleApps) { app in
                    NavigationLink(value: app) {
                        AppRow(app: app)
                            .padding(.horizontal, 20)
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 90)
                }
                if visibleApps.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        Text("No betas match that filter.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Image(systemName: "flask.fill")
                .font(.system(size: 18))
                .foregroundColor(Theme.blue.opacity(0.6))
            Text("Beta Shelf indexes public TestFlight links only.\nAvailability is checked live against testflight.apple.com.")
                .font(.system(size: 11))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}

// MARK: - Featured hero card

struct FeaturedCard: View {
    let app: BetaApp

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Theme.gradient(for: app.genre))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(LinearGradient(colors: [.clear, .black.opacity(0.35)],
                                             startPoint: .center, endPoint: .bottom))
                )

            Circle()
                .fill(.white.opacity(0.09))
                .frame(width: 260, height: 260)
                .offset(x: 120, y: -120)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(app.genre.uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(1.4)
                        .foregroundColor(.white.opacity(0.85))
                    Spacer()
                    StatusBadge(status: app.status)
                        .background(Capsule().fill(.white.opacity(0.16)))
                }

                Spacer(minLength: 0)

                AppIconView(url: app.icon, size: 74, radius: 17)

                Text(app.name)
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(app.developer.isEmpty ? "Public beta" : app.developer)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text("Open beta")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.white.opacity(0.2)))
                    if app.ratingCount > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill").font(.system(size: 9))
                            Text(String(format: "%.1f", app.rating))
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.white.opacity(0.9))
                    }
                    Spacer()
                    Text("JOIN")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .tracking(0.5)
                        .foregroundColor(.black.opacity(0.75))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.white))
                }
            }
            .padding(18)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 28)
        .padding(.top, 6)
    }
}

#Preview {
    BrowseView().environmentObject(CatalogStore.shared)
}
