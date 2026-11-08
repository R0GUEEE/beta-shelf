import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: CatalogStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance") private var appearance: String = "system"
    @State private var confirmClear = false

    private var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
    }
    private var build: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "1"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.brandGradient)
                                .frame(width: 58, height: 58)
                            Image(systemName: "flask.fill")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Beta Shelf")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            Text("Version \(version) (\(build))")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Catalogue") {
                    LabeledContent("Public betas", value: "\(store.openBetas.count)")
                    LabeledContent("Saved links", value: "\(store.userBetas.count)")
                    LabeledContent("Categories", value: "\(store.genres.count)")
                    if let last = store.lastRefresh {
                        LabeledContent("Last full check", value: last.formatted(date: .abbreviated, time: .shortened))
                    }
                    Button {
                        Task { await store.refreshStatuses(force: true, limit: 200) }
                    } label: {
                        HStack {
                            Label("Check every link now", systemImage: "arrow.triangle.2.circlepath")
                            Spacer()
                            if store.isRefreshing {
                                ProgressView().controlSize(.small)
                            }
                        }
                    }
                    .disabled(store.isRefreshing)
                }

                Section("Appearance") {
                    Picker("Theme", selection: $appearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button(role: .destructive) {
                        confirmClear = true
                    } label: {
                        Label("Clear availability cache", systemImage: "trash")
                    }
                } footer: {
                    Text("Clearing the cache does not remove saved links; statuses are re-checked on the next refresh.")
                }

                Section("About") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How Beta Shelf works")
                            .font(.system(size: 13, weight: .semibold))
                        Text("The app ships with a catalogue of public TestFlight invites and their App Store metadata. Each link is checked against Apple's public invite page on testflight.apple.com — the same page a tester would open — to read the beta's current availability. No account, no API key, no analytics.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
                        Text("Beta Shelf is not affiliated with Apple Inc. TestFlight is a trademark of Apple Inc. Public links are published by developers and can be withdrawn at any time.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
                            .padding(.top, 2)
                    }
                    .padding(.vertical, 4)

                    Link(destination: URL(string: "https://testflight.apple.com")!) {
                        Label("testflight.apple.com", systemImage: "safari")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Clear the availability cache?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear cache", role: .destructive) { store.clearCache() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Every link will show as unchecked until the next refresh.")
            }
        }
    }
}

#Preview {
    SettingsView().environmentObject(CatalogStore.shared)
}
