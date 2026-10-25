import SwiftUI
import WebKit
import ReaderDomain

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

private struct ArticleDetailView: View {
    var session: ReaderSession
    let article: ArticleSnapshot
    @State private var page = makeArticlePage()
    @State private var extracting = false

    var body: some View {
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
                    if let url = article.url { Link("Original", destination: url) }
                    Menu(LocalizedStringResource("Article", bundle: .atURL(#bundle.bundleURL)), systemImage: "ellipsis") {
                        Button(LocalizedStringResource("Load full text", bundle: .atURL(#bundle.bundleURL)), systemImage: "doc.text.magnifyingglass") {
                            Task {
                                extracting = true
                                defer { extracting = false }
                                await session.extract(article)
                            }
                        }
                        .disabled(extracting || article.url == nil)
                    }
                    if extracting { ProgressView().controlSize(.small) }
                }
                .buttonStyle(.borderless)
                .font(.callout)
            }
            .padding()
            Divider()
            WebView(page)
                .task(id: article.html + article.text) { await loadHTML() }
        }
    }

    private func loadHTML() async {
        let content = article.html.isEmpty ? "<pre>\(escape(article.text))</pre>" : article.html
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src https: data:; style-src 'unsafe-inline'; media-src https:;">
        <style>:root{color-scheme:light dark}body{font:17px -apple-system;line-height:1.6;max-width:48rem;margin:auto;padding:1.2rem;overflow-wrap:anywhere}img,video{max-width:100%;height:auto}pre{white-space:pre-wrap}a{color:LinkText}</style>
        </head><body>\(content)</body></html>
        """
        do {
            for try await _ in page.load(html: html, baseURL: article.url ?? URL(fileURLWithPath: "/")) { }
        } catch is CancellationError {
        } catch { session.errorMessage = error.localizedDescription }
    }

    private func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
    }
}

@MainActor
private func makeArticlePage() -> WebPage {
    var configuration = WebPage.Configuration()
    configuration.defaultNavigationPreferences.allowsContentJavaScript = false
    return WebPage(configuration: configuration)
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
