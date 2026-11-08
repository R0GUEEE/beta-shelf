import Foundation

/// Availability of a public TestFlight link, as reported by testflight.apple.com.
enum BetaStatus: String, Codable {
    case open
    case full
    case closed
    case unknown

    var label: String {
        switch self {
        case .open: return "Accepting testers"
        case .full: return "Beta is full"
        case .closed: return "Link closed"
        case .unknown: return "Status unknown"
        }
    }

    var shortLabel: String {
        switch self {
        case .open: return "OPEN"
        case .full: return "FULL"
        case .closed: return "CLOSED"
        case .unknown: return "BETA"
        }
    }
}

struct BetaApp: Identifiable, Hashable, Codable {
    var code: String
    var name: String
    var betaName: String
    var developer: String
    var genre: String
    var icon: String
    var summary: String
    var releaseNotes: String
    var screenshots: [String]
    var rating: Double
    var ratingCount: Int
    var price: String
    var version: String
    var minOS: String
    var appStoreURL: String
    var trackId: Int
    var full: Bool

    // runtime state
    var status: BetaStatus = .open
    var lastChecked: Date?
    var isUserAdded: Bool = false
    var addedAt: Date?
    var storeURL: String?

    var id: String { code }

    var joinURL: URL { URL(string: "itms-beta://testflight.apple.com/join/\(code)")! }
    var webURL: URL { URL(string: "https://testflight.apple.com/join/\(code)")! }
    var shareURL: URL { webURL }
    var iconURL: URL? { URL(string: icon) }

    var subtitle: String {
        var bits: [String] = []
        if !genre.isEmpty { bits.append(genre) }
        if ratingCount > 0 { bits.append(String(format: "%.1f ★", rating)) }
        if !price.isEmpty { bits.append(price) }
        return bits.joined(separator: " · ")
    }

    var ratingText: String {
        ratingCount > 0 ? String(format: "%.1f", rating) : "—"
    }

    enum CodingKeys: String, CodingKey {
        case code, name, betaName, developer, genre, icon, description, releaseNotes, screenshots
        case rating, ratingCount, price, version, minOS, appStoreURL, trackId, full
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = try c.decode(String.self, forKey: .code)
        name = (try? c.decode(String.self, forKey: .name)) ?? code
        betaName = (try? c.decode(String.self, forKey: .betaName)) ?? name
        developer = (try? c.decode(String.self, forKey: .developer)) ?? ""
        genre = (try? c.decode(String.self, forKey: .genre)) ?? ""
        icon = (try? c.decode(String.self, forKey: .icon)) ?? ""
        summary = (try? c.decode(String.self, forKey: .description)) ?? ""
        releaseNotes = (try? c.decode(String.self, forKey: .releaseNotes)) ?? ""
        screenshots = (try? c.decode([String].self, forKey: .screenshots)) ?? []
        rating = (try? c.decode(Double.self, forKey: .rating)) ?? 0
        ratingCount = (try? c.decode(Int.self, forKey: .ratingCount)) ?? 0
        price = (try? c.decode(String.self, forKey: .price)) ?? ""
        version = (try? c.decode(String.self, forKey: .version)) ?? ""
        minOS = (try? c.decode(String.self, forKey: .minOS)) ?? ""
        appStoreURL = (try? c.decode(String.self, forKey: .appStoreURL)) ?? ""
        trackId = (try? c.decode(Int.self, forKey: .trackId)) ?? 0
        full = (try? c.decode(Bool.self, forKey: .full)) ?? false
        status = full ? .full : .open
    }

    init(code: String, name: String, betaName: String? = nil, developer: String = "",
         genre: String = "", icon: String = "", summary: String = "", releaseNotes: String = "",
         screenshots: [String] = [], rating: Double = 0, ratingCount: Int = 0, price: String = "",
         version: String = "", minOS: String = "", appStoreURL: String = "", trackId: Int = 0,
         full: Bool = false) {
        self.code = code
        self.name = name
        self.betaName = betaName ?? name
        self.developer = developer
        self.genre = genre
        self.icon = icon
        self.summary = summary
        self.releaseNotes = releaseNotes
        self.screenshots = screenshots
        self.rating = rating
        self.ratingCount = ratingCount
        self.price = price
        self.version = version
        self.minOS = minOS
        self.appStoreURL = appStoreURL
        self.trackId = trackId
        self.full = full
        self.status = full ? .full : .open
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(code, forKey: .code)
        try c.encode(name, forKey: .name)
        try c.encode(betaName, forKey: .betaName)
        try c.encode(developer, forKey: .developer)
        try c.encode(genre, forKey: .genre)
        try c.encode(icon, forKey: .icon)
        try c.encode(summary, forKey: .description)
        try c.encode(releaseNotes, forKey: .releaseNotes)
        try c.encode(screenshots, forKey: .screenshots)
        try c.encode(rating, forKey: .rating)
        try c.encode(ratingCount, forKey: .ratingCount)
        try c.encode(price, forKey: .price)
        try c.encode(version, forKey: .version)
        try c.encode(minOS, forKey: .minOS)
        try c.encode(appStoreURL, forKey: .appStoreURL)
        try c.encode(trackId, forKey: .trackId)
        try c.encode(full, forKey: .full)
    }
}

/// A result from the public iTunes Search API.
struct StoreApp: Identifiable, Decodable {
    let trackId: Int
    let trackName: String
    let sellerName: String?
    let artistName: String?
    let primaryGenreName: String?
    let averageUserRating: Double?
    let userRatingCount: Int?
    let formattedPrice: String?
    let artworkUrl512: String?
    let artworkUrl100: String?
    let screenshotUrls: [String]?
    let trackViewUrl: String?
    let description: String?
    let version: String?
    let minimumOsVersion: String?

    var id: Int { trackId }
    var icon: String { artworkUrl512 ?? artworkUrl100 ?? "" }
    var developer: String { sellerName ?? artistName ?? "" }
    var sub: String {
        var bits: [String] = []
        if let g = primaryGenreName { bits.append(g) }
        if let r = averageUserRating, let n = userRatingCount, n > 0 {
            bits.append(String(format: "%.1f ★", r))
        }
        if let p = formattedPrice { bits.append(p) }
        return bits.joined(separator: " · ")
    }
}

struct ITunesResponse: Decodable {
    let resultCount: Int
    let results: [StoreApp]
}
