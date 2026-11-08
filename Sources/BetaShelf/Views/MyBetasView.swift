import SwiftUI

struct MyBetasView: View {
    @EnvironmentObject private var store: CatalogStore
    @State private var showAdd = false
    @State private var detail: BetaApp? = nil

    var body: some View {
        NavigationStack {
            Group {
                if store.userBetas.isEmpty {
                    emptyState
                } else {
                    List {
                        Section {
                            ForEach(store.userBetas) { app in
                                NavigationLink(value: app) {
                                    AppRow(app: app)
                                }
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    store.remove(store.userBetas[index])
                                }
                            }
                        } header: {
                            Text("\(store.userBetas.count) saved betas")
                        } footer: {
                            Text("Saved links are stored on this device only. Availability is re-checked against testflight.apple.com each time you refresh.")
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        for app in store.userBetas {
                            await store.checkSingle(app)
                        }
                    }
                }
            }
            .navigationTitle("My Betas")
            .navigationDestination(for: BetaApp.self) { app in
                BetaDetailView(app: app)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) { AddBetaSheet() }
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Theme.brandGradient)
                        .frame(width: 96, height: 96)
                        .opacity(0.12)
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(Theme.brandGradient)
                }
                .padding(.top, 40)

                VStack(spacing: 8) {
                    Text("Your stack is empty")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("Add any public TestFlight invite and Beta Shelf will track its availability, even if it isn't in the built-in catalogue.")
                        .font(.system(size: 14))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 32)
                }

                Button {
                    showAdd = true
                } label: {
                    Label("Add a TestFlight link", systemImage: "link.badge.plus")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .foregroundColor(.white)
                        .background(Theme.brandGradient, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 6)

                VStack(alignment: .leading, spacing: 10) {
                    tip("flask.fill", "Paste testflight.apple.com/join/… or just the 8-character code.")
                    tip("checkmark.seal.fill", "We read Apple's public invite page, so no account is needed.")
                    tip("hand.raised.fill", "Nothing leaves the device except those public lookups.")
                }
                .padding(16)
                .card(radius: 18, material: .thinMaterial)
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 40)
        }
    }

    private func tip(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .foregroundColor(Theme.blue)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Add sheet

struct AddBetaSheet: View {
    var prefillName: String? = nil

    @EnvironmentObject private var store: CatalogStore
    @Environment(\.dismiss) private var dismiss

    @State private var input = ""
    @State private var isWorking = false
    @State private var preview: ResolvedBeta? = nil
    @State private var errorText: String? = nil
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Add a public beta")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text("Paste a TestFlight invite link or its code. Beta Shelf reads the public invite page to confirm it works.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 8) {
                        TextField("https://testflight.apple.com/join/…", text: $input)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, design: .monospaced))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .focused($focused)
                            .onChange(of: input) { _ in
                                preview = nil
                                errorText = nil
                            }
                        if !input.isEmpty {
                            Button {
                                input = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                            }
                        }
                        Button {
                            Task { await resolve() }
                        } label: {
                            if isWorking {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("Check")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || isWorking)
                    }
                    .padding(12)
                    .background(Color(uiColor: .secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if let errorText {
                        Label(errorText, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.orange)
                    }

                    if let preview {
                        previewCard(preview)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Where to find links")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Developers post public links on social media, Discord and their websites. Any link of the form testflight.apple.com/join/CODE works here.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        if let prefillName {
                            Text("Looking for \(prefillName)? Ask the developer for their public TestFlight link.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(14)
                    .card(radius: 16, material: .thinMaterial)
                }
                .padding(20)
            }
            .navigationTitle("Add beta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(preview == nil || isWorking)
                    .fontWeight(.semibold)
                }
            }
            .onAppear { focused = true }
        }
    }

    private func previewCard(_ beta: ResolvedBeta) -> some View {
        HStack(spacing: 12) {
            if let icon = beta.icon {
                AppIconView(url: icon, size: 56)
            } else {
                AppIconView(url: "", size: 56)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(beta.name)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text("testflight.apple.com/join/\(beta.code)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                HStack(spacing: 6) {
                    StatusBadge(status: beta.status)
                    if store.allApps.contains(where: { $0.code == beta.code }) {
                        Text("already indexed")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
        .padding(14)
        .card(radius: 16, material: .thinMaterial)
    }

    private func resolve() async {
        isWorking = true
        errorText = nil
        do {
            preview = try await TestFlightResolver.resolve(rawInput: input)
        } catch {
            errorText = error.localizedDescription
            preview = nil
        }
        isWorking = false
    }

    private func save() async {
        isWorking = true
        do {
            _ = try await store.addBeta(input: input)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
        isWorking = false
    }
}

#Preview {
    MyBetasView().environmentObject(CatalogStore.shared)
}
