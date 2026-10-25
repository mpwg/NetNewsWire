import SwiftUI
import Observation
import WebKit
import ReaderDomain
import ReaderContent
import CryptoKit

struct ReaderDetail: View {
    var session: ReaderSession

    var body: some View {
        VStack(spacing: 0) {
            if let article = session.selectedArticle {
                ArticleDetailView(session: session, article: article)
                    .id(article.id)
            } else if let digest = session.selectedDigest {
                DigestDetailView(session: session, digest: digest)
                    .id(digest.revision)
            } else if session.timelineSelection.count > 1 {
                ContentUnavailableView {
                    Label { Text("Selected entries: \(session.timelineSelection.count)", bundle: #bundle) } icon: { Image(systemName: "checklist") }
                        .accessibilityIdentifier("selectionSummary")
                } description: {
                    Text("Choose an action for the selected entries.", bundle: #bundle)
                } actions: {
                    Menu {
                        TimelineStatusActions(session: session, target: session.statusTarget(for: session.timelineSelection))
                    } label: {
                        Text("Selection actions", bundle: #bundle)
                    }
                }
            } else {
                ContentUnavailableView(LocalizedStringResource("Select an article", bundle: .atURL(#bundle.bundleURL)), systemImage: "newspaper",
                                       description: Text("Articles and daily digests remain accessible together.", bundle: #bundle))
            }
        }
        .task(id: session.selection) { await session.loadSelectedArticle() }
    }
}

struct ArticleDetailView: View {
    var session: ReaderSession
    let article: ArticleSnapshot
    @State private var reader: ReaderArticleState
    @Environment(\.openURL) private var openURL

    init(session: ReaderSession, article: ArticleSnapshot, reader: ReaderArticleState = ReaderArticleState()) {
        self.session = session
        self.article = article
        self.reader = reader
    }

    var body: some View {
        let request = reader.extractionRequest
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(article.title).font(.title2.bold()).textSelection(.enabled)
                    .accessibilityIdentifier("articleDetailTitle")
                HStack {
                    Button(article.read ? LocalizedStringResource("Mark unread", bundle: .atURL(#bundle.bundleURL)) : LocalizedStringResource("Mark read", bundle: .atURL(#bundle.bundleURL)), systemImage: article.read ? "envelope.badge" : "checkmark.circle") {
                        Task { await session.setStatus([article.id], field: .read, value: !article.read) }
                    }
                    Button(article.starred ? LocalizedStringResource("Remove star", bundle: .atURL(#bundle.bundleURL)) : LocalizedStringResource("Star", bundle: .atURL(#bundle.bundleURL)), systemImage: article.starred ? "star.fill" : "star") {
                        Task { await session.setStatus([article.id], field: .starred, value: !article.starred) }
                    }
                    if let url = article.url, ReaderWebContentPolicy.permitsExternalLink(url) { Link("Original", destination: url) }
                    Menu(LocalizedStringResource("Article", bundle: .atURL(#bundle.bundleURL)), systemImage: "ellipsis") {
                        Button(LocalizedStringResource("Load full text", bundle: .atURL(#bundle.bundleURL)), systemImage: "doc.text.magnifyingglass") {
                            reader.beginExtraction()
                        }
                        .disabled(reader.extracting || article.url == nil)
                        .accessibilityIdentifier("loadFullText")
                    }
                    .accessibilityIdentifier("articleActions")
                    if reader.extracting { ProgressView().controlSize(.small) }
                }
                .buttonStyle(.borderless)
                .font(.callout)
                if let error = session.fullTextError {
                    Label {
                        Text("Full text is unavailable. Showing saved feed content.", bundle: #bundle)
                    } icon: { Image(systemName: "exclamationmark.triangle") }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help(Text(error))
                    .accessibilityIdentifier("fullTextUnavailable")
                }
            }
            .padding()
            Divider()
            WebView(reader.page)
                .webViewLinkPreviews(.disabled)
                .webViewBackForwardNavigationGestures(.disabled)
                .task(id: article.html + article.text) { await loadHTML() }
        }
        .task(id: request) {
            guard let request, !Task.isCancelled, reader.extractionRequest == request else { return }
            defer { if reader.extractionRequest == request { reader.extracting = false } }
            await session.extract(article)
        }
        .onAppear { reader.links.open = { [openURL] url in openURL(url) } }
        .onDisappear { reader.links.open = nil; reader.page.stopLoading() }
    }

    private func loadHTML() async {
        do {
            try await ReaderArticleDocument.load(article, into: reader.page)
        } catch is CancellationError {
        } catch {
            if !Task.isCancelled, session.selection == .article(article.id) {
                session.errorMessage = error.localizedDescription
            }
        }
    }

}

@MainActor @Observable
final class ReaderArticleState {
    let page: WebPage
    var extracting = false
    var extractionRequest: UUID?

    let links: ReaderArticleLinks

    init(page: WebPage? = nil) {
        let links = ReaderArticleLinks()
        self.links = links
        self.page = page ?? ReaderArticleDocument.makePage(openLink: { [weak links] url in links?.open?(url) })
    }

    func beginExtraction() {
        extracting = true
        extractionRequest = UUID()
    }
}

@MainActor
final class ReaderArticleLinks {
    var open: ((URL) -> Void)?
}

/// Only sanitized passive article markup reaches the visible document.
enum ReaderArticleDocument {
    private static let style = ":root{color-scheme:light dark}body{font:17px -apple-system;line-height:1.6;max-width:48rem;margin:auto;padding:1.2rem;overflow-wrap:anywhere}pre{white-space:pre-wrap}a{color:LinkText}"

    @MainActor
    static func makePage(configuration: WebPage.Configuration = WebPage.Configuration(), openLink: ((URL) -> Void)? = nil) -> WebPage {
        let configuration = ReaderWebContentPolicy.configuration(configuration)
        return WebPage(configuration: configuration,
                       navigationDecider: ReaderWebNavigationPolicy(openLink: openLink, controller: configuration.userContentController))
    }

    @MainActor
    static func load(_ article: ArticleSnapshot, into page: WebPage) async throws {
        let source = article.html.isEmpty ? "<pre>\(escape(article.text))</pre>" : article.html
        let safeContent = try await ReaderWebContentPolicy.sanitizedHTML(source, baseURL: article.url, page: page)
        try Task.checkCancellation()
        try await withTaskCancellationHandler {
            for try await _ in page.load(html: html(safeContent: safeContent)) { try Task.checkCancellation() }
            try Task.checkCancellation()
        } onCancel: {
            Task { @MainActor [weak page] in page?.stopLoading() }
        }
    }

    static func html(safeContent: String) -> String {
        let styleHash = Data(SHA256.hash(data: Data(style.utf8))).base64EncodedString()
        return """
        <!doctype html><html><head>
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'sha256-\(styleHash)'; style-src-attr 'none'; form-action 'none'; base-uri 'none'">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>\(style)</style>
        </head><body>\(safeContent)</body></html>
        """
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
    }
}

private struct DigestDetailView: View {
    var session: ReaderSession
    let digest: DigestSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label(LocalizedStringResource("Daily digest", bundle: .atURL(#bundle.bundleURL)), systemImage: "sparkles").font(.largeTitle.bold())
                Text(digest.day, format: .dateTime.weekday().day().month().year()).foregroundStyle(.secondary)
                Text("AI digest · \(digest.sources.count) original articles", bundle: #bundle)
                    .font(.callout).foregroundStyle(.secondary)
                if let newest = session.digests.first(where: { $0.id == digest.id }), newest.revision != digest.revision {
                    Button(LocalizedStringResource("Open updated digest", bundle: .atURL(#bundle.bundleURL)), systemImage: "arrow.clockwise") { session.openLatestDigest() }
                }
                if let warning = digest.warning {
                    Label(warning, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                }
                Button(LocalizedStringResource("Mark digest read", bundle: .atURL(#bundle.bundleURL)), systemImage: "checkmark.circle") {
                    Task { await session.setStatus(digest.sources, field: .read, value: true) }
                }
                .buttonStyle(.borderedProminent)
                Text("Marks only the originals in this revision. New articles remain unread.", bundle: #bundle)
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(Array(digest.sections.enumerated()), id: \.offset) { _, section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title).font(.title3.bold())
                        Text(section.text).textSelection(.enabled)
                        ForEach(section.sources) { source in
                            if let article = session.sourceArticles.first(where: { $0.id == source }) {
                                sourceButton(article)
                            }
                        }
                    }
                }
                Divider()
                Text("All original articles", bundle: #bundle).font(.title3.bold())
                if session.loadingSources { ProgressView(LocalizedStringResource("Loading sources", bundle: .atURL(#bundle.bundleURL))) }
                ForEach(session.sourceArticles) { article in sourceButton(article) }
                if !session.loadingSources && session.sourceArticles.count < digest.sources.count {
                    Label(LocalizedStringResource("Some original articles are no longer available locally.", bundle: .atURL(#bundle.bundleURL)), systemImage: "exclamationmark.triangle")
                }
            }
            .padding()
            .frame(maxWidth: 800, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .task(id: digest.revision) { await session.loadSources(digest) }
    }

    private func sourceButton(_ article: ArticleSnapshot) -> some View {
        Button { session.selection = .article(article.id) } label: {
            Label(article.title, systemImage: article.read ? "doc.text" : "circle")
                .multilineTextAlignment(.leading)
        }
        .buttonStyle(.borderless)
    }
}
