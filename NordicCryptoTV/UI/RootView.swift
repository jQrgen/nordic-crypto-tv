import SwiftUI

struct RootView: View {
    @State private var store = FeedStore()
    @State private var router = Router()
    @State private var screen: Screen = .top

    var body: some View {
        @Bindable var router = router
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                HeaderBar(screen: $screen)
                StatusStrip(store: store)
            }
            .padding(.horizontal, 80)
            .padding(.top, 40)

            Group {
                switch screen {
                case .top: TopNewsView(store: store)
                case .nordics: NordicsView(store: store)
                case .events: EventsView(store: store)
                case .brief: NewsletterView(store: store)
                }
            }
            .padding(.horizontal, 80)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            TickerTape(items: store.news, lang: store.lang)
        }
        .background(Theme.background)
        .ignoresSafeArea()
        .environment(router)
        .task { await store.run() }
        #if DEBUG
        .onAppear(perform: applyScreenshotArguments)
        #endif
        .fullScreenCover(item: $router.story) { item in
            StoryDetailView(item: item, lang: store.lang)
        }
        .fullScreenCover(item: $router.event) { event in
            EventDetailView(event: event, lang: store.lang)
        }
        .fullScreenCover(item: $router.reader) { issue in
            IssueReader(issue: issue, lang: store.lang)
        }
        .fullScreenCover(item: $router.newsreel) { reel in
            if let url = reel.playableURL {
                NewsreelPlayer(url: url, title: store.issues.first?.title(for: store.lang) ?? "Nordic Crypto")
                    .ignoresSafeArea()
            }
        }
    }
}

#if DEBUG
extension RootView {
    /// `-NCScreen nordics|events|brief` and `-NCOpen story|event|reader|newsreel` for screenshots.
    private func applyScreenshotArguments() {
        let args = ProcessInfo.processInfo.arguments
        func value(_ flag: String) -> String? {
            args.firstIndex(of: flag).flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }
        }
        if let name = value("-NCScreen"), let s = Screen(rawValue: name) { screen = s }
        switch value("-NCOpen") {
        case "story": router.story = store.news.first
        case "event": router.event = store.upcomingEvents.first
        case "reader": router.reader = store.issues.first.flatMap { store.issue($0.id) }
        case "newsreel": router.newsreel = store.issues.first.flatMap { store.issue($0.id)?.video }
        default: break
        }
    }
}
#endif

extension Newsreel: Identifiable {
    var id: String { playableURL?.absoluteString ?? "" }
}
