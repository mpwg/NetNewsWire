import SwiftUI
import ReaderDomain
import ReaderPersistence
import ReaderSync
import ReaderContent
import ReaderIntelligence
import ReaderUI

@main
struct ReaderApplication: App {
    private let bootstrap: ReaderBootstrap

    init() { bootstrap = ReaderBootstrap() }

    var body: some Scene {
        WindowGroup(id: "reader") {
            if let services = bootstrap.services {
                #if DEBUG && os(macOS)
                VStack(spacing: 0) {
                    ReaderWindow(services: services)
                    if let fixture = bootstrap.imageLoadFixture {
                        Divider()
                        ReaderImageLoadPanel(fixture: fixture)
                    }
                    if let fixture = bootstrap.timelineFixture {
                        Divider()
                        ReaderTimelinePanel(fixture: fixture)
                    }
                    if let fixture = bootstrap.contentFixture {
                        Divider()
                        ReaderContentPanel(fixture: fixture)
                    }
                }
                #else
                ReaderWindow(services: services)
                #endif
            } else {
                ContentUnavailableView("Reader could not start", systemImage: "externaldrive.badge.exclamationmark",
                                       description: Text(bootstrap.errorMessage ?? String(localized: "The local data store is unavailable.")))
                    .padding()
            }
        }
        .defaultSize(width: 1200, height: 800)
        #if os(macOS)
        .defaultWindowPlacement { _, context in
            let available = context.defaultDisplay.visibleRect.insetBy(dx: 24, dy: 24)
            return WindowPlacement(size: CGSize(width: min(1200, available.width), height: min(800, available.height)))
        }
        #endif
    }
}

@MainActor
private final class ReaderBootstrap {
    let services: ReaderServices?
    let errorMessage: String?
    #if DEBUG && os(macOS)
    private(set) var imageLoadFixture: ReaderImageLoadFixture?
    private(set) var timelineFixture: ReaderTimelineFixture?
    private(set) var contentFixture: ReaderContentFixture?
    #endif

    init() {
        do {
            let bundleID = Bundle.main.bundleIdentifier ?? "eu.mpwg.reader.debug"
            let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                        appropriateFor: nil, create: true).appendingPathComponent(bundleID, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let uiTesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
            let store = try ReaderStore(url: uiTesting ? nil : directory.appendingPathComponent("Reader.store"), inMemory: uiTesting)
            #if DEBUG && os(macOS)
            if uiTesting && ProcessInfo.processInfo.arguments.contains("--ui-testing-content") {
                let fixture = ReaderContentFixture(store: store)
                contentFixture = fixture
                services = ReaderServices(repository: store, content: fixture.content)
                errorMessage = nil
                return
            }
            if uiTesting && ProcessInfo.processInfo.arguments.contains("--ui-testing-timeline") {
                let fixture = ReaderTimelineFixture(store: store)
                timelineFixture = fixture
                services = ReaderServices(repository: fixture.repository)
                errorMessage = nil
                return
            }
            if uiTesting && ProcessInfo.processInfo.arguments.contains("--ui-testing-image-load") {
                let fixture = ReaderImageLoadFixture(store: store)
                imageLoadFixture = fixture
                services = ReaderServices(repository: store, images: fixture.images)
                errorMessage = nil
                return
            }
            #endif
            let credentials = KeychainCredentialStore(service: bundleID)
            let client = FreshRSSClient(repository: store, credentials: credentials)
            let content = ArticleContentService()
            let digests = DigestCoordinator(repository: store, generator: AppleSummaryGenerator(), extractor: content)
            services = ReaderServices(repository: store, credentials: credentials, client: client, digests: digests, content: content)
            errorMessage = nil
        } catch {
            services = nil
            errorMessage = error.localizedDescription
        }
    }
}
