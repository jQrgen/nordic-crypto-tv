import SwiftUI

/// The front page. Top stories are the three newest; "More news" continues
/// from the fourth, grouped by day, with times instead of rank numbers.
struct TodayView: View {
    @Environment(FeedStore.self) private var store
    @State private var showAlerts = false

    var body: some View {
        content
            .background(NLBackground())
            #if !os(tvOS)
            .toolbar {
                ToolbarItem {
                    Link(destination: APIConfig.telegram) { Label("Chat on Telegram", systemImage: "paperplane") }
                }
            }
            #endif
            #if os(iOS)
            .toolbar {
                ToolbarItem {
                    Button { showAlerts = true } label: { Label("Notifications", systemImage: "bell") }
                }
            }
            .sheet(isPresented: $showAlerts) {
                NavigationStack { AlertSettingsView() }
            }
            #if DEBUG
            .onAppear { if ProcessInfo.processInfo.arguments.contains("-NCAlerts") { showAlerts = true } }
            #endif
            #elseif os(macOS)
            .toolbar {
                ToolbarItem {
                    SettingsLink { Label("Notifications", systemImage: "bell") }
                }
            }
            #endif
            #if !os(tvOS)
            .navigationTitle("Today")
            .refreshable { await store.refresh() }
            #endif
            #if os(macOS)
            .toolbar {
                ToolbarItem {
                    Button { Task { await store.refresh() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                        .keyboardShortcut("r")
                }
            }
            #endif
    }

    @ViewBuilder private var content: some View {
        #if os(tvOS)
        EmptyView()  // Apple TV shows SignageView instead.
        #else
        AdaptiveToday()
        #endif
    }
}

// MARK: - Coming up

struct ComingUpPanel: View {
    let limit: Int
    #if os(tvOS)
    var focused: FocusState<String?>.Binding
    #endif
    @Environment(FeedStore.self) private var store
    @Environment(Router.self) private var router

    #if !os(tvOS)
    init(limit: Int) { self.limit = limit }
    #else
    init(limit: Int, focused: FocusState<String?>.Binding) {
        self.limit = limit
        self.focused = focused
    }
    #endif

    var body: some View {
        let events = store.upcomingEvents
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Coming up")
            if events.isEmpty, let issue = store.issues.first {
                NewsletterCard(issue: issue, height: 300)
            }
            ForEach(events.prefix(limit)) { event in
                EventMiniCard(event: event)
                    #if os(tvOS)
                    .focused(focused, equals: "e-" + event.id)
                    #endif
            }
            if !events.isEmpty {
                Button { router.tab = .events } label: {
                    Label("All \(events.count) events", systemImage: "calendar")
                }
                .buttonStyle(.bordered)
                #if os(tvOS)
                .focused(focused, equals: "all-events")
                #endif
            }
        }
    }
}

// MARK: - iPhone, iPad, Mac, Vision Pro

#if !os(tvOS)
private struct AdaptiveToday: View {
    @Environment(FeedStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var width: CGFloat = 0

    var body: some View {
        ScrollView {
            Group {
                if width >= 700 && !typeSize.isAccessibilitySize {
                    WideToday(width: width)
                } else {
                    CompactToday()
                }
            }
            .padding(.horizontal, width >= 700 ? NLMetrics.margin + 8 : NLMetrics.margin)
            .padding(.bottom, 24)
            .frame(maxWidth: 1280)
            .frame(maxWidth: .infinity)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}

private struct CompactToday: View {
    @Environment(FeedStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let top = store.topStories
        LazyVStack(alignment: .leading, spacing: 20, pinnedViews: [.sectionHeaders]) {
            StatusPill(store: store)
            if let lead = top.first {
                LeadCard(item: lead, height: typeSize.isAccessibilitySize ? 560 : 420, summaryLines: 0)
            }

            if !store.upcomingEvents.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Coming up") {
                        Button("All") { router.tab = .events }
                    }
                    if typeSize.isAccessibilitySize {
                        ForEach(store.upcomingEvents.prefix(3)) { EventMiniCard(event: $0) }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 12) {
                                ForEach(store.upcomingEvents.prefix(8)) { event in
                                    EventMiniCard(event: event).frame(width: 280)
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.viewAligned)
                        .scrollClipDisabled()
                    }
                }
            }

            if top.count > 1 {
                SectionHeader(title: "Top stories")
                ForEach(top.dropFirst()) { CompactStoryCard(item: $0) }
            }

            if let issue = store.issues.first {
                NewsletterCard(issue: issue, height: 190)
            }

            MoreNewsSections(columns: 1)
            TelegramCard()
            Disclaimer()
        }
    }
}

private struct WideToday: View {
    let width: CGFloat
    @Environment(FeedStore.self) private var store

    var body: some View {
        let top = store.topStories
        VStack(alignment: .leading, spacing: 28) {
            StatusPill(store: store)
            HStack(alignment: .top, spacing: NLMetrics.gutter) {
                VStack(spacing: NLMetrics.gutter) {
                    if let lead = top.first {
                        LeadCard(item: lead, height: 380, summaryLines: 2, animated: isVision)
                    }
                    HStack(spacing: NLMetrics.gutter) {
                        ForEach(top.dropFirst()) { SecondaryCard(item: $0, height: 220) }
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: NLMetrics.gutter) {
                    ComingUpPanel(limit: 4)
                    if let issue = store.issues.first {
                        NewsletterCard(issue: issue, height: 210)
                    }
                    TelegramCard()
                }
                .frame(width: max(300, width / 3 - 40))
            }
            MoreNewsSections(columns: width >= 1200 ? 3 : 2)
            Disclaimer()
        }
    }

    private var isVision: Bool {
        #if os(visionOS)
        true
        #else
        false
        #endif
    }
}

private struct MoreNewsSections: View {
    let columns: Int
    @Environment(FeedStore.self) private var store

    var body: some View {
        SectionHeader(title: "More news", count: max(store.news.count - 3, 0))
        ForEach(store.moreNewsByDay, id: \.day) { group in
            Section {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: NLMetrics.gutter, alignment: .top), count: columns),
                          spacing: NLMetrics.gutter) {
                    ForEach(group.items) { NewsRow(item: $0) }
                }
            } header: {
                Text(Formats.dayHeader(group.day, lang: store.lang))
                    .font(NLFont.kicker)
                    .foregroundStyle(NL.textSecondary)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NL.bg.opacity(0.92))
            }
        }
    }
}
#endif

#if !os(tvOS)
/// Invitation to the community chat on Telegram.
struct TelegramCard: View {
    var body: some View {
        Link(destination: APIConfig.telegram) {
            HStack(spacing: 16) {
                Image(systemName: "paperplane.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Color(hex: 0x229ED9), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Join the Nordic Crypto chat on Telegram")
                        .font(NLFont.row)
                        .foregroundStyle(NL.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(verbatim: APIConfig.telegramHandle)
                        .font(NLFont.caption)
                        .foregroundStyle(NL.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(NL.textTertiary)
            }
            .padding(NLMetrics.cardPadding * 0.75)
            .nlGlass(cornerRadius: NLMetrics.rowRadius)
            .contentShape(Rectangle())
        }
        .nlCardButton()
    }
}
#endif
