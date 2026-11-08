import Foundation
import SwiftUI

struct StatusRecord: Codable {
    var status: BetaStatus
    var checkedAt: Date
    var message: String
}

@MainActor
final class CatalogStore: ObservableObject {
    static let shared = CatalogStore()

    @Published private(set) var bundled: [BetaApp] = []
    @Published private(set) var userBetas: [BetaApp] = []
    @Published private(set) var statuses: [String: StatusRecord] = [:]
    @Published var isRefreshing = false
    @Published var lastRefresh: Date?
    @Published var refreshProgress: Double = 0

    private let fm = FileManager.default
    private let staleInterval: TimeInterval = 60 * 60 * 6

    private var supportDir: URL {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        return base.appendingPathComponent("BetaShelf", isDirectory: true)
    }
    private var userFile: URL { supportDir.appendingPathComponent("user_betas.json") }
    private var statusFile: URL { supportDir.appendingPathComponent("status_cache.json") }

    init() {
        loadBundled()
        loadUserBetas()
        loadStatuses()
    }

    // MARK: - Loading

    private func loadBundled() {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            bundled = []
            return
        }
        let decoder = JSONDecoder()
        let raw = (try? decoder.decode([BetaApp].self, from: data)) ?? []
        bundled = raw.map { app in
            var copy = app
            copy.status = app.full ? .full : .open
            return copy
        }
    }

    private func loadUserBetas() {
        guard let data = try? Data(contentsOf: userFile),
              let list = try? JSONDecoder().decode([BetaApp].self, from: data) else { return }
        userBetas = list.map { app in
            var copy = app
            copy.isUserAdded = true
            return copy
        }
    }

    private func loadStatuses() {
        guard let data = try? Data(contentsOf: statusFile),
              let map = try? JSONDecoder().decode([String: StatusRecord].self, from: data) else { return }
        statuses = map
    }

    private func persistUserBetas() {
        ensureSupportDir()
        if let data = try? JSONEncoder().encode(userBetas) {
            try? data.write(to: userFile, options: .atomic)
        }
    }

    private func persistStatuses() {
        ensureSupportDir()
        if let data = try? JSONEncoder().encode(statuses) {
            try? data.write(to: statusFile, options: .atomic)
        }
    }

    private func ensureSupportDir() {
        if !fm.fileExists(atPath: supportDir.path) {
            try? fm.createDirectory(at: supportDir, withIntermediateDirectories: true)
        }
    }

    // MARK: - Derived collections

    /// Everything the user can browse: bundled catalogue plus their own links,
    /// each merged with the freshest known status.
    var allApps: [BetaApp] {
        var seen = Set<String>()
        var out: [BetaApp] = []
        for var app in userBetas + bundled {
            let key = app.code
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            if let rec = statuses[key] {
                app.status = rec.status
                app.lastChecked = rec.checkedAt
            } else if let cached = statuses[app.code] {
                app.status = cached.status
                app.lastChecked = cached.checkedAt
            }
            out.append(app)
        }
        return out
    }

    var openBetas: [BetaApp] { allApps.filter { $0.status != .closed } }

    var featured: [BetaApp] {
        let pool = openBetas.filter { !$0.screenshots.isEmpty && $0.status == .open }
        let ranked = pool.sorted {
            if $0.ratingCount == $1.ratingCount { return $0.rating > $1.rating }
            return $0.ratingCount > $1.ratingCount
        }
        return Array(ranked.prefix(5))
    }

    var newAndNoteworthy: [BetaApp] {
        openBetas
            .filter { !$0.summary.isEmpty }
            .sorted { ($0.addedAt ?? .distantPast) > ($1.addedAt ?? .distantPast) }
    }

    var genres: [(String, Int)] {
        var counts: [String: Int] = [:]
        for app in openBetas where !app.genre.isEmpty {
            counts[app.genre, default: 0] += 1
        }
        return counts.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map { ($0.key, $0.value) }
    }

    func apps(in genre: String) -> [BetaApp] {
        openBetas.filter { $0.genre == genre }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func search(_ query: String) -> [BetaApp] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        return openBetas.filter { app in
            app.name.lowercased().contains(q)
                || app.betaName.lowercased().contains(q)
                || app.developer.lowercased().contains(q)
                || app.genre.lowercased().contains(q)
                || app.summary.lowercased().contains(q)
        }.sorted { lhs, rhs in
            let ln = lhs.name.lowercased(), rn = rhs.name.lowercased()
            let lp = ln.hasPrefix(q), rp = rn.hasPrefix(q)
            if lp != rp { return lp }
            return ln < rn
        }
    }

    func hasBeta(forTrackId id: Int) -> BetaApp? {
        guard id > 0 else { return nil }
        return allApps.first { $0.trackId == id }
    }

    // MARK: - Mutations

    func status(for code: String) -> BetaStatus {
        statuses[code]?.status ?? .unknown
    }

    func addBeta(input: String) async throws -> BetaApp {
        let resolved = try await TestFlightResolver.resolve(rawInput: input)
        var app = BetaApp(code: resolved.code,
                          name: resolved.name,
                          developer: "",
                          icon: resolved.icon ?? "",
                          summary: resolved.message)
        app.isUserAdded = true
        app.addedAt = Date()
        app.status = resolved.status

        // Try to dress it up with App Store metadata when the app is public.
        if let store = await AppStoreClient.bestMatch(for: resolved.name) {
            app.name = store.trackName
            app.developer = store.developer
            app.genre = store.primaryGenreName ?? ""
            app.icon = store.icon.isEmpty ? app.icon : store.icon
            app.summary = store.description ?? app.summary
            app.screenshots = Array((store.screenshotUrls ?? []).prefix(6))
            app.rating = store.averageUserRating ?? 0
            app.ratingCount = store.userRatingCount ?? 0
            app.price = store.formattedPrice ?? ""
            app.version = store.version ?? ""
            app.minOS = store.minimumOsVersion ?? ""
            app.appStoreURL = store.trackViewUrl ?? ""
            app.trackId = store.trackId
        }

        userBetas.removeAll { $0.code == app.code }
        userBetas.insert(app, at: 0)
        persistUserBetas()
        statuses[app.code] = StatusRecord(status: resolved.status, checkedAt: Date(), message: resolved.message)
        persistStatuses()
        return app
    }

    func remove(_ app: BetaApp) {
        userBetas.removeAll { $0.code == app.code }
        persistUserBetas()
    }

    func isUserAdded(_ app: BetaApp) -> Bool {
        userBetas.contains { $0.code == app.code }
    }

    // MARK: - Live status refresh

    /// Re-reads testflight.apple.com for the stalest links. Limits concurrency so
    /// a big catalogue does not hammer Apple in one burst.
    func refreshStatuses(force: Bool = false, limit: Int = 60) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        refreshProgress = 0
        defer { isRefreshing = false }

        let now = Date()
        let candidates = allApps
            .filter { app in
                if force { return true }
                guard let rec = statuses[app.code] else { return true }
                return now.timeIntervalSince(rec.checkedAt) > staleInterval
            }
            .sorted { ($0.status == .open ? 0 : 1) < ($1.status == .open ? 0 : 1) }
            .prefix(limit)
            .map { $0 }

        guard !candidates.isEmpty else {
            lastRefresh = Date()
            refreshProgress = 1
            return
        }

        var done = 0.0
        let total = Double(candidates.count)
        for chunk in candidates.chunked(into: 5) {
            await withTaskGroup(of: (String, StatusRecord)?.self) { group in
                for app in chunk {
                    group.addTask {
                        guard let resolved = try? await TestFlightResolver.resolve(code: app.code) else {
                            return nil
                        }
                        return (app.code, StatusRecord(status: resolved.status,
                                                       checkedAt: Date(),
                                                       message: resolved.message))
                    }
                }
                for await result in group {
                    done += 1
                    if let (code, rec) = result {
                        statuses[code] = rec
                    }
                    refreshProgress = done / total
                }
            }
            persistStatuses()
        }
        lastRefresh = Date()
        refreshProgress = 1
    }

    func checkSingle(_ app: BetaApp) async {
        if let resolved = try? await TestFlightResolver.resolve(code: app.code) {
            statuses[app.code] = StatusRecord(status: resolved.status,
                                              checkedAt: Date(),
                                              message: resolved.message)
            persistStatuses()
        }
    }

    func clearCache() {
        statuses = [:]
        persistStatuses()
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
