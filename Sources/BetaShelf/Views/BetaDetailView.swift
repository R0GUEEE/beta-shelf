import SwiftUI

struct BetaDetailView: View {
    let app: BetaApp
    @EnvironmentObject private var store: CatalogStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var expanded = false
    @State private var addedMessage: String? = nil

    private var live: BetaApp {
        store.allApps.first { $0.code == app.code } ?? app
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                actionRow
                screenshotStrip
                descriptionBlock
                whatsNewBlock
                betaAccessCard
                informationBlock
                footer
            }
            .padding(.bottom, 40)
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle(live.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                ShareLink(item: live.shareURL) {
                    Image(systemName: "square.and.arrow.up")
                }
                Menu {
                    Button {
                        UIPasteboard.general.string = "https://testflight.apple.com/join/\(live.code)"
                        addedMessage = "Link copied"
                    } label: {
                        Label("Copy invite link", systemImage: "link")
                    }
                    if !live.appStoreURL.isEmpty, let url = URL(string: live.appStoreURL) {
                        Link(destination: url) {
                            Label("View on the App Store", systemImage: "arrow.up.right.square")
                        }
                    }
                    if store.isUserAdded(live) {
                        Button(role: .destructive) {
                            store.remove(live)
                            dismiss()
                        } label: {
                            Label("Remove from My Betas", systemImage: "trash")
                        }
                    } else {
                        Button {
                            Task {
                                _ = try? await store.addBeta(input: live.code)
                                addedMessage = "Added to My Betas"
                            }
                        } label: {
                            Label("Add to My Betas", systemImage: "plus.circle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .overlay(alignment: .top) {
            if let addedMessage {
                Text(addedMessage)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(nanoseconds: 1_800_000_000)
                        withAnimation { self.addedMessage = nil }
                    }
            }
        }
        .animation(.easeInOut, value: addedMessage)
    }

    // MARK: Hero

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 0)
                .fill(Theme.gradient(for: live.genre))
                .frame(height: 268)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 220, height: 220)
                        .offset(x: 60, y: -70)
                }

            HStack(alignment: .bottom, spacing: 16) {
                AppIconView(url: live.icon, size: 104, radius: 24)
                VStack(alignment: .leading, spacing: 4) {
                    Text(live.name)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                    Text(live.developer.isEmpty ? "Independent developer" : live.developer)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.82))
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        StatusBadge(status: live.status)
                        Text("Public beta")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 22)
        }
    }

    // MARK: Actions

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                openURL(live.joinURL) { accepted in
                    if !accepted, let store = URL(string: "https://apps.apple.com/app/testflight/id899247664") {
                        openURL(store)
                    }
                }
            } label: {
                VStack(spacing: 3) {
                    Text("Join Beta")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text(live.status == .open ? "Opens TestFlight" : "Link may be closed")
                        .font(.system(size: 10, weight: .medium))
                        .opacity(0.75)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .foregroundColor(.white)
                .background(Theme.blue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(live.status == .closed)

            Link(destination: URL(string: "https://testflight.apple.com/join/\(live.code)")!) {
                VStack(spacing: 3) {
                    Image(systemName: "globe")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Web page")
                        .font(.system(size: 10, weight: .medium))
                }
                .frame(width: 82)
                .padding(.vertical, 9)
                .foregroundColor(Theme.blue)
                .background(Theme.blue.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: Screenshots

    @ViewBuilder
    private var screenshotStrip: some View {
        if !live.screenshots.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Preview")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .padding(.horizontal, 20)
                    .padding(.top, 26)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(live.screenshots, id: \.self) { shot in
                            AsyncImage(url: URL(string: shot)) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFill()
                                } else {
                                    Rectangle()
                                        .fill(Color(uiColor: .secondarySystemBackground))
                                        .overlay(ProgressView().controlSize(.small))
                                }
                            }
                            .frame(width: 200, height: 433)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: Description

    private var descriptionBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("About this beta")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                Spacer()
                Button(expanded ? "Less" : "More") {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.blue)
            }

            Text(live.summary.isEmpty
                 ? "The developer hasn't published App Store details for this build yet. Open the invite link to see the beta description in TestFlight."
                 : live.summary)
                .font(.system(size: 14))
                .lineSpacing(3)
                .lineLimit(expanded ? nil : 6)
                .foregroundColor(.primary.opacity(0.85))
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
    }

    @ViewBuilder
    private var whatsNewBlock: some View {
        if !live.releaseNotes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("What's New")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                Text(live.releaseNotes)
                    .font(.system(size: 13))
                    .lineSpacing(2)
                    .lineLimit(expanded ? nil : 8)
                    .foregroundColor(.primary.opacity(0.8))
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
    }

    // MARK: Beta access

    private var betaAccessCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flask.fill")
                    .foregroundColor(Theme.blue)
                Text("Beta access")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                StatusBadge(status: live.status, compact: false)
            }

            Text(store.statuses[live.code]?.message ?? "Checked against testflight.apple.com.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineSpacing(2)

            HStack {
                Button {
                    Task { await store.checkSingle(live) }
                } label: {
                    Label("Check now", systemImage: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                }
                Spacer()
                if let checked = live.lastChecked {
                    Text("Checked \(checked.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .card(radius: 18, material: .thinMaterial)
        .padding(.horizontal, 20)
        .padding(.top, 26)
    }

    // MARK: Information

    private var informationBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Information")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .padding(.bottom, 10)

            infoRow("Seller", live.developer.isEmpty ? "—" : live.developer)
            Divider()
            infoRow("Category", live.genre.isEmpty ? "—" : live.genre)
            Divider()
            infoRow("Price", live.price.isEmpty ? "Free" : live.price)
            Divider()
            infoRow("App Store version", live.version.isEmpty ? "—" : live.version)
            Divider()
            infoRow("Requires", live.minOS.isEmpty ? "iOS" : "iOS \(live.minOS)+")
            Divider()
            infoRow("Invite code", live.code, monospaced: true)
            Divider()
            infoHStack
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
    }

    private var infoHStack: some View {
        HStack(alignment: .top) {
            Text("Link")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(width: 130, alignment: .leading)
            Text("testflight.apple.com/join/\(live.code)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Theme.blue)
                .lineLimit(2)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
    }

    private func infoRow(_ label: String, _ value: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(width: 130, alignment: .leading)
            Text(value)
                .font(.system(size: 13, weight: .medium, design: monospaced ? .monospaced : .default))
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Beta Shelf is an independent browser for public TestFlight links. It is not affiliated with Apple. Testers must have the TestFlight app installed.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineSpacing(2)
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
    }
}

#Preview {
    NavigationStack {
        BetaDetailView(app: BetaApp(code: "dQCtQSf1", name: "CROON: Real-time Dubbing",
                                    developer: "Example Labs", genre: "Music",
                                    icon: "", summary: "Real-time AI dubbing for your videos.",
                                    screenshots: [], rating: 4.6, ratingCount: 120))
    }
    .environmentObject(CatalogStore.shared)
}
