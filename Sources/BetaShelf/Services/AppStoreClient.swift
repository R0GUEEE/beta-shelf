import Foundation

/// Thin wrapper over the public iTunes Search API (no key, no backend).
enum AppStoreClient {
    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        cfg.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: cfg)
    }()

    static func search(term: String, limit: Int = 25, country: String = "us") async throws -> [StoreApp] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var comps = URLComponents(string: "https://itunes.apple.com/search")!
        comps.queryItems = [
            URLQueryItem(name: "term", value: trimmed),
            URLQueryItem(name: "entity", value: "software"),
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return try await fetch(comps.url!)
    }

    static func lookup(trackId: Int, country: String = "us") async throws -> StoreApp? {
        var comps = URLComponents(string: "https://itunes.apple.com/lookup")!
        comps.queryItems = [
            URLQueryItem(name: "id", value: String(trackId)),
            URLQueryItem(name: "country", value: country)
        ]
        return try await fetch(comps.url!).first
    }

    /// Used when a beta has no iTunes metadata (unreleased apps): search by its
    /// TestFlight display name and accept only a close name match.
    static func bestMatch(for name: String) async -> StoreApp? {
        guard let results = try? await search(term: name, limit: 5) else { return nil }
        let target = normalize(name)
        return results.first { r in
            let t = normalize(r.trackName)
            return t == target || t.hasPrefix(target) || target.hasPrefix(t)
        } ?? results.first
    }

    private static func fetch(_ url: URL) async throws -> [StoreApp] {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ITunesResponse.self, from: data).results
    }

    private static func normalize(_ s: String) -> String {
        s.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
