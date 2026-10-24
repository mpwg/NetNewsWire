import SwiftUI
import ReaderDomain

struct AccountConnectionView: View {
    let session: ReaderSession
    @Environment(\.dismiss) private var dismiss
    @State private var server = ""
    @State private var username = ""
    @State private var password = ""
    @State private var working = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("FreshRSS") {
                    TextField(LocalizedStringResource("API URL (https://…/api/greader.php)", bundle: .atURL(#bundle.bundleURL)), text: $server)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("serverURL")
                    TextField(LocalizedStringResource("Username", bundle: .atURL(#bundle.bundleURL)), text: $username)
                        .textContentType(.username).autocorrectionDisabled()
                        .accessibilityIdentifier("username")
                    SecureField(LocalizedStringResource("API password", bundle: .atURL(#bundle.bundleURL)), text: $password)
                        .textContentType(.password)
                        .accessibilityIdentifier("apiPassword")
                }
                Section {
                    Text("Enable API access in FreshRSS and use its separate API password. Credentials are stored in this device’s Keychain.", bundle: #bundle)
                        .font(.callout).foregroundStyle(.secondary)
                }
                if let error { Text(error).foregroundStyle(.red) }
                if working { ProgressView(LocalizedStringResource("Connecting", bundle: .atURL(#bundle.bundleURL))) }
            }
            .formStyle(.grouped)
            .navigationTitle(Text("Connect FreshRSS", bundle: #bundle))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(LocalizedStringResource("Cancel", bundle: .atURL(#bundle.bundleURL))) { dismiss() }.disabled(working).accessibilityIdentifier("cancelConnection") }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringResource("Connect", bundle: .atURL(#bundle.bundleURL))) {
                        Task {
                            working = true
                            defer { working = false }
                            do {
                                try await session.connect(server: server.trimmingCharacters(in: .whitespacesAndNewlines),
                                                          username: username.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
                                password = ""
                                dismiss()
                            } catch { self.error = error.localizedDescription }
                        }
                    }
                    .disabled(working || server.isEmpty || username.isEmpty || password.isEmpty)
                    .accessibilityIdentifier("submitConnection")
                }
            }
        }
        .frame(idealWidth: 500, idealHeight: 440)
    }
}

struct FeedCreationView: View {
    let session: ReaderSession
    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @State private var title = ""
    @State private var accountID: UUID?
    @State private var folderID = ""
    @State private var working = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Picker(LocalizedStringResource("Account", bundle: .atURL(#bundle.bundleURL)), selection: $accountID) {
                    ForEach(session.accounts) { account in Text(account.username).tag(Optional(account.id)) }
                }
                TextField(LocalizedStringResource("Feed URL", bundle: .atURL(#bundle.bundleURL)), text: $url).textContentType(.URL).autocorrectionDisabled()
                TextField(LocalizedStringResource("Name (optional)", bundle: .atURL(#bundle.bundleURL)), text: $title)
                TextField(LocalizedStringResource("Folder name (optional)", bundle: .atURL(#bundle.bundleURL)), text: $folderID)
                if let error { Text(error).foregroundStyle(.red) }
                if working { ProgressView() }
            }
            .formStyle(.grouped)
            .navigationTitle(Text("Add feed", bundle: #bundle))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(LocalizedStringResource("Cancel", bundle: .atURL(#bundle.bundleURL))) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringResource("Add", bundle: .atURL(#bundle.bundleURL))) { Task { await add() } }.disabled(url.isEmpty || working)
                }
            }
        }
        .frame(idealWidth: 450, idealHeight: 360)
        .task { accountID = session.accounts.first?.id }
    }

    private func add() async {
        guard let feedURL = URL(string: url), ["https", "http"].contains(feedURL.scheme), feedURL.host != nil,
              let account = session.accounts.first(where: { $0.id == accountID }), let client = session.services.client else {
            error = String(localized: "Choose a valid feed URL and an account.", bundle: #bundle)
            return
        }
        working = true
        defer { working = false }
        do {
            try await client.addFeed(account: account, url: feedURL, title: title.isEmpty ? nil : title,
                                     folderID: folderID.isEmpty ? nil : "user/-/label/" + folderID)
            try await client.refresh(account: account)
            session.services.didChange()
            await session.reload()
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct FeedSettingsView: View {
    let session: ReaderSession
    let feed: FeedSnapshot
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var mode: FeedMode
    @State private var cloudAllowed: Bool
    @State private var folderID: String
    @State private var working = false
    @State private var error: String?

    init(session: ReaderSession, feed: FeedSnapshot) {
        self.session = session
        self.feed = feed
        let preferences = session.preferences(for: feed)
        self.title = feed.title
        self.mode = preferences.mode
        self.cloudAllowed = preferences.cloudAllowed
        self.folderID = feed.folderIDs.first ?? ""
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Feed") {
                    TextField("Name", text: $title)
                    Picker(LocalizedStringResource("Folder", bundle: .atURL(#bundle.bundleURL)), selection: $folderID) {
                        Text("No folder", bundle: #bundle).tag("")
                        ForEach(session.folders.filter { $0.accountID == feed.id.accountID }) { folder in
                            Text(folder.title).tag(folder.remoteID)
                        }
                    }
                    if let url = feed.homePageURL { Link(LocalizedStringResource("Open website", bundle: .atURL(#bundle.bundleURL)), destination: url) }
                }
                Section(LocalizedStringResource("Display on this device", bundle: .atURL(#bundle.bundleURL))) {
                    Picker(LocalizedStringResource("Mode", bundle: .atURL(#bundle.bundleURL)), selection: $mode) {
                        Text("Normal").tag(FeedMode.normal)
                        Text("Daily digest", bundle: #bundle).tag(FeedMode.digest)
                    }
                    Text("A daily digest groups articles. All originals remain accessible in the feed, search and source links.", bundle: #bundle)
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle(LocalizedStringResource("Allow Apple Private Cloud Compute", bundle: .atURL(#bundle.bundleURL)), isOn: $cloudAllowed)
                        .disabled(!session.services.privateCloudComputeConfigured)
                    if !session.services.privateCloudComputeConfigured {
                        Text("This build uses on-device AI. PCC requires separate Apple authorization and matching signed provisioning.", bundle: #bundle)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Without this permission, only the on-device Apple model processes text. PCC requires Apple authorization and available quota; enabling it does not guarantee availability.", bundle: #bundle)
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let error { Text(error).foregroundStyle(.red) }
                if working { ProgressView() }
            }
            .formStyle(.grouped)
            .navigationTitle(Text("Feed settings", bundle: #bundle))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(LocalizedStringResource("Cancel", bundle: .atURL(#bundle.bundleURL))) { dismiss() }.disabled(working) }
                ToolbarItem(placement: .confirmationAction) { Button(LocalizedStringResource("Save", bundle: .atURL(#bundle.bundleURL))) { Task { await save() } }.disabled(working || title.isEmpty) }
            }
        }
        .frame(idealWidth: 500, idealHeight: 540)
    }

    private func save() async {
        working = true
        defer { working = false }
        do {
            if let client = session.services.client, let account = session.accounts.first(where: { $0.id == feed.id.accountID }) {
                if title != feed.title { try await client.renameFeed(account: account, feedID: feed.id.remoteID, title: title) }
                if folderID != (feed.folderIDs.first ?? "") {
                    try await client.moveFeed(account: account, feedID: feed.id.remoteID,
                                              fromFolderID: feed.folderIDs.first, toFolderID: folderID.isEmpty ? nil : folderID)
                }
                if title != feed.title || folderID != (feed.folderIDs.first ?? "") { try await client.refresh(account: account) }
            }
            var preferences = session.preferences(for: feed)
            preferences.mode = mode
            preferences.cloudAllowed = cloudAllowed
            await session.savePreferences(preferences)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct FolderSettingsView: View {
    let session: ReaderSession
    let folder: FolderSnapshot
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var working = false
    @State private var error: String?

    init(session: ReaderSession, folder: FolderSnapshot) {
        self.session = session
        self.folder = folder
        self.title = folder.title
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(LocalizedStringResource("Folder name", bundle: .atURL(#bundle.bundleURL)), text: $title)
                if let error { Text(error).foregroundStyle(.red) }
                if working { ProgressView() }
            }
            .formStyle(.grouped)
            .navigationTitle(Text("Rename folder", bundle: #bundle))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(LocalizedStringResource("Cancel", bundle: .atURL(#bundle.bundleURL))) { dismiss() }.disabled(working) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringResource("Save", bundle: .atURL(#bundle.bundleURL))) {
                        Task {
                            working = true
                            defer { working = false }
                            do {
                                guard let account = session.accounts.first(where: { $0.id == folder.accountID }),
                                      let client = session.services.client else { return }
                                try await client.renameFolder(account: account, folderID: folder.remoteID, title: title)
                                try await client.refresh(account: account)
                                session.services.didChange()
                                await session.reload()
                                dismiss()
                            } catch { self.error = error.localizedDescription }
                        }
                    }
                    .disabled(working || title.isEmpty)
                }
            }
        }
        .frame(idealWidth: 400, idealHeight: 250)
    }
}
