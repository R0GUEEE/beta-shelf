import SwiftUI

enum Theme {
    static let blue = Color(red: 0.04, green: 0.52, blue: 1.0)
    static let indigo = Color(red: 0.35, green: 0.34, blue: 0.84)
    static let pink = Color(red: 0.98, green: 0.36, blue: 0.55)
    static let orange = Color(red: 1.0, green: 0.58, blue: 0.24)
    static let mint = Color(red: 0.0, green: 0.78, blue: 0.75)

    static let brandGradient = LinearGradient(
        colors: [Color(red: 0.05, green: 0.42, blue: 0.98), Color(red: 0.36, green: 0.28, blue: 0.95)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let dusk = LinearGradient(
        colors: [Color(red: 0.10, green: 0.11, blue: 0.20), Color(red: 0.22, green: 0.15, blue: 0.38)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static func gradient(for genre: String) -> LinearGradient {
        let palettes: [String: [Color]] = [
            "Games": [Color(red: 0.94, green: 0.33, blue: 0.52), Color(red: 0.62, green: 0.22, blue: 0.86)],
            "Developer Tools": [Color(red: 0.10, green: 0.45, blue: 0.92), Color(red: 0.10, green: 0.72, blue: 0.80)],
            "Productivity": [Color(red: 0.13, green: 0.60, blue: 0.50), Color(red: 0.36, green: 0.80, blue: 0.55)],
            "Social Networking": [Color(red: 0.98, green: 0.50, blue: 0.25), Color(red: 0.92, green: 0.26, blue: 0.42)],
            "Utilities": [Color(red: 0.30, green: 0.34, blue: 0.44), Color(red: 0.13, green: 0.16, blue: 0.24)],
            "Photo & Video": [Color(red: 0.85, green: 0.30, blue: 0.60), Color(red: 0.42, green: 0.25, blue: 0.78)],
            "Music": [Color(red: 0.92, green: 0.25, blue: 0.45), Color(red: 0.55, green: 0.20, blue: 0.60)],
            "Finance": [Color(red: 0.10, green: 0.45, blue: 0.35), Color(red: 0.05, green: 0.30, blue: 0.45)],
            "Health & Fitness": [Color(red: 0.40, green: 0.75, blue: 0.35), Color(red: 0.10, green: 0.55, blue: 0.55)],
            "Education": [Color(red: 0.22, green: 0.42, blue: 0.95), Color(red: 0.55, green: 0.35, blue: 0.80)]
        ]
        let colors = palettes[genre] ?? [Color(red: 0.25, green: 0.30, blue: 0.55), Color(red: 0.12, green: 0.15, blue: 0.30)]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct CardBackground: ViewModifier {
    var radius: CGFloat = 22
    var material: Material = .regular
    func body(content: Content) -> some View {
        content
            .background(material, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    func card(radius: CGFloat = 22, material: Material = .regular) -> some View {
        modifier(CardBackground(radius: radius, material: material))
    }
}

/// Rounded app icon with a hairline border and graceful placeholder.
struct AppIconView: View {
    let url: String
    var size: CGFloat = 64
    var radius: CGFloat? = nil

    var body: some View {
        AsyncImage(url: URL(string: url), transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                placeholder
            default:
                placeholder.overlay(ProgressView().controlSize(.small).opacity(0.6))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius ?? size * 0.225, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius ?? size * 0.225, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.16), radius: size * 0.08, x: 0, y: size * 0.035)
    }

    private var placeholder: some View {
        LinearGradient(colors: [Theme.indigo.opacity(0.55), Theme.blue.opacity(0.35)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(
                Image(systemName: "flask.fill")
                    .font(.system(size: size * 0.34, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            )
    }
}

/// Status pill ("OPEN", "FULL", "CLOSED").
struct StatusBadge: View {
    let status: BetaStatus
    var compact: Bool = true

    var body: some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: compact ? 5 : 6, height: compact ? 5 : 6)
            Text(compact ? status.shortLabel : status.label)
                .font(.system(size: compact ? 9 : 11, weight: .heavy, design: .rounded))
                .tracking(compact ? 0.4 : 0.2)
        }
        .padding(.horizontal, compact ? 6 : 9)
        .padding(.vertical, compact ? 3 : 4)
        .foregroundColor(color)
        .background(color.opacity(0.13), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.22), lineWidth: 0.5))
    }

    private var color: Color {
        switch status {
        case .open: return Color(red: 0.10, green: 0.72, blue: 0.38)
        case .full: return Theme.orange
        case .closed: return .secondary
        case .unknown: return Theme.blue
        }
    }
}

/// The App Store "GET" pill, repurposed as "JOIN".
struct JoinPill: View {
    var title: String = "JOIN"
    var emphasized: Bool = false

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .tracking(0.3)
            .foregroundColor(emphasized ? .white : Theme.blue)
            .padding(.horizontal, 18)
            .padding(.vertical, 7)
            .background {
                if emphasized {
                    Capsule().fill(Theme.blue)
                } else {
                    Capsule().fill(Theme.blue.opacity(0.13))
                }
            }
    }
}

struct StarsView: View {
    let rating: Double
    var size: CGFloat = 9

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<5) { i in
                Image(systemName: symbol(for: i))
                    .font(.system(size: size))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func symbol(for index: Int) -> String {
        let value = rating - Double(index)
        if value >= 0.75 { return "star.fill" }
        if value >= 0.25 { return "star.leadinghalf.filled" }
        return "star"
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if let action {
                Button("See All", action: action)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.blue)
            }
        }
        .padding(.horizontal, 20)
    }
}

/// Compact tile used in horizontal shelves.
struct AppTile: View {
    let app: BetaApp
    var width: CGFloat = 132

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            AppIconView(url: app.icon, size: width * 0.86, radius: width * 0.2)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(app.developer.isEmpty ? app.genre : app.developer)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    StarsView(rating: app.rating)
                    if app.ratingCount > 0 {
                        Text(app.ratingText)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    Spacer(minLength: 0)
                    StatusBadge(status: app.status)
                }
                .padding(.top, 1)
            }
        }
        .frame(width: width, alignment: .leading)
    }
}

/// List row used in vertical lists.
struct AppRow: View {
    let app: BetaApp
    var showStatus: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            AppIconView(url: app.icon, size: 58)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text(app.developer.isEmpty ? app.genre : app.developer)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    StarsView(rating: app.rating, size: 8)
                    Text(app.ratingText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    if showStatus {
                        StatusBadge(status: app.status)
                    }
                }
            }
            Spacer(minLength: 6)
            JoinPill()
        }
        .padding(.vertical, 4)
    }
}
