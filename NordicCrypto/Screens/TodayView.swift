import SwiftUI

/// The front page. Top stories are the three newest; "More news" continues
/// from the fourth, grouped by day, with times instead of rank numbers.
struct TodayView: View {
    @Environment(FeedStore.self) private var store

    var body: some View {
        content
            .background(NLBackground())
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
        TodayTV()
        #else
        AdaptiveToday()
        #endif
    }
}

// MARK: - Apple TV

#if os(tvOS)
private struct TodayTV: View {
    @Environment(FeedStore.self) private var store
    @Environment(Router.self) private var router
    @FocusState private var focused: String?
    @State private var lastInput = Date()
    @State private var ambientIndex = 0
    @State private var ambient = false

    var body: some View {
        let top = store.topStories
        let lead = top.isEmpty ? nil : top[ambientIndex % top.count]
        let secondary = top.filter { $0.id != lead?.id }
        ScrollView {
            VStack(alignment: .leading, spacing: 44) {
                HStack(spacing: 24) {
                    Wordmark()
                    Spacer()
                    RadioButton()
                        .focused($focused, equals: "radio")
                    StatusPill(store: store).opacity(ambient ? 0.5 : 1)
                }
                .focusSection()

                HStack(alignment: .top, spacing: NLMetrics.gutter) {
                    if let lead {
                        LeadCard(item: lead, height: 470, summaryLines: 2, animated: true)
                            .id(lead.id)
                            .transition(.opacity)
                            .focused($focused, equals: "lead")
                    }
                    ComingUpPanel(limit: 3, focused: $focused)
                        .frame(width: 640, height: 470, alignment: .top)
                }
                .focusSection()

                HStack(alignment: .top, spacing: NLMetrics.gutter) {
                    ForEach(secondary) { item in
                        SecondaryCard(item: item, height: 300)
                            .focused($focused, equals: "s-" + item.id)
                    }
                    if let issue = store.issues.first {
                        NewsletterCard(issue: issue, height: 300)
                            .frame(width: 640)
                            .focused($focused, equals: "newsletter")
                    }
                }
                .focusSection()

                VStack(alignment: .leading, spacing: 24) {
                    SectionHeader(title: "More news", count: max(store.news.count - 3, 0))
                    ForEach(store.moreNewsByDay, id: \.day) { group in
                        VStack(alignment: .leading, spacing: 16) {
                            Text(Formats.dayHeader(group.day, lang: store.lang))
                                .font(NLFont.kicker)
                                .foregroundStyle(NL.textSecondary)
                            ScrollView(.horizontal) {
                                LazyHStack(spacing: NLMetrics.gutter) {
                                    ForEach(group.items) { item in
                                        NewsRow(item: item, lines: 3)
                                            .frame(width: 560, height: 230)
                                            .focused($focused, equals: "n-" + item.id)
                                    }
                                }
                                .padding(.vertical, 12)
                            }
                            .scrollClipDisabled()
                        }
                        .focusSection()
                    }
                }

                VStack(alignment: .leading, spacing: 20) {
                    SectionHeader(title: "By country")
                    HStack(spacing: 28) {
                        ForEach(Country.allCases) { country in
                            CountryTile(country: country, height: 230)
                                .focused($focused, equals: "c-" + country.rawValue)
                        }
                    }
                }
                .focusSection()

                Disclaimer()
            }
            .padding(.horizontal, NLMetrics.margin)
            .padding(.vertical, 30)
        }
        .scrollClipDisabled()
        .defaultFocus($focused, "lead")
        .onChange(of: focused) { _, _ in
            lastInput = .now
            if ambient { withAnimation(.smooth) { ambient = false; ambientIndex = 0 } }
        }
        .task(id: store.topStories.map(\.id)) { await runAmbient() }
    }

    /// The TV never sleeps, so after 3 idle minutes the lead slot rotates
    /// through the top stories to keep the picture changing.
    private func runAmbient() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(20))
            guard Date.now.timeIntervalSince(lastInput) > 180, store.topStories.count > 1 else { continue }
            withAnimation(.easeInOut(duration: 1.2)) {
                ambient = true
                ambientIndex = (ambientIndex + 1) % store.topStories.count
            }
        }
    }
}

/// Shows what is playing and switches Radio Norge on or off.
private struct RadioButton: View {
    @Environment(Radio.self) private var radio

    var body: some View {
        Button { radio.toggle() } label: {
            Label {
                Text(verbatim: Radio.name)
            } icon: {
                Image(systemName: radio.isOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .symbolEffect(.variableColor.iterative, isActive: radio.isPlaying)
            }
            .font(NLFont.caption.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .tint(radio.isOn ? NL.accent : NL.textTertiary)
        .accessibilityValue(Text(radio.isOn ? "On" : "Off"))
    }
}
#endif

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
