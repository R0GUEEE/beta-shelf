import Foundation

struct ResolvedBeta {
    let code: String
    let name: String
    let icon: String?
    let message: String
    let status: BetaStatus
}

enum ResolverError: LocalizedError {
    case badCode
    case network(String)

    var errorDescription: String? {
        switch self {
        case .badCode: return "That link doesn't contain a TestFlight invite code."
        case .network(let m): return m
        }
    }
}

/// Reads the public invite page on testflight.apple.com, which is HTML that
/// server-renders the beta's title, icon and current availability.
enum TestFlightResolver {
    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 18
        cfg.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            "Accept-Language": "en-US,en;q=0.9"
        ]
        return URLSession(configuration: cfg)
    }()

    /// Accepts a full join URL, a malformed one, or a bare code.
    static func extractCode(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let r = trimmed.range(of: "join/") {
            let tail = trimmed[r.upperBound...]
            let code = tail.prefix { $0.isLetter || $0.isNumber }
            return code.count >= 6 ? String(code) : nil
        }
        let code = trimmed.prefix { $0.isLetter || $0.isNumber }
        return code.count >= 6 ? String(code) : nil
    }

    static func resolve(rawInput: String) async throws -> ResolvedBeta {
        guard let code = extractCode(from: rawInput) else { throw ResolverError.badCode }
        return try await resolve(code: code)
    }

    static func resolve(code: String) async throws -> ResolvedBeta {
        guard let url = URL(string: "https://testflight.apple.com/join/\(code)") else {
            throw ResolverError.badCode
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ResolverError.network(error.localizedDescription)
        }
        let http = response as? HTTPURLResponse
        guard let statusCode = http?.statusCode else { throw ResolverError.network("Bad response.") }
        guard statusCode == 200 else {
            return ResolvedBeta(code: code, name: "Unknown beta", icon: nil,
                                message: "Apple returned HTTP \(statusCode) for this link.",
                                status: .closed)
        }
        let html = String(decoding: data, as: UTF8.self)
        let title = firstMatch(#"<title>(.*?)</title>"#, in: html) ?? ""
        var name = title
        for prefix in ["Join the ", "Join "] where name.hasPrefix(prefix) {
            name.removeFirst(prefix.count)
        }
        for suffix in [" beta - TestFlight - Apple", " - TestFlight - Apple"] where name.hasSuffix(suffix) {
            name.removeLast(suffix.count)
        }
        name = name.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { name = "TestFlight beta" }

        var icon: String? = nil
        if let og = firstMatch(#"og:image" content="([^"]+)""#, in: html) {
            icon = og.replacingOccurrences(of: #"/\d+x\d+ia-[^/]*$"#,
                                           with: "/512x512bb.png",
                                           options: .regularExpression)
        }

        let statusBlock = firstMatch(#"<div class="beta-status">(.*?)</div>\s*</div>"#, in: html) ?? ""
        let message = statusBlock
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let lower = html.lowercased()
        let status: BetaStatus
        if ["this beta is full", "beta is full", "no longer accepting", "isn't accepting new testers",
            "is not accepting new testers", "stopped accepting"].contains(where: { lower.contains($0) }) {
            status = .full
        } else if ["this beta is closed", "beta has expired", "this beta has expired"].contains(where: { lower.contains($0) }) {
            status = .closed
        } else {
            status = .open
        }

        return ResolvedBeta(code: code, name: name, icon: icon, message: message, status: status)
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern,
                                                options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let m = re.firstMatch(in: text, options: [], range: range) else { return nil }
        guard m.numberOfRanges > 1, let r = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }
}
