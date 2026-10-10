import SwiftUI

// MARK: - Story

struct StoryDetailView: View {
    @State var item: NewsItem
    @Environment(FeedStore.self) private var store
    @FocusState private var summaryFocused: Bool

    var body: some View {
        #if os(tvOS)
        tvBody
        #else
        standardBody
        #endif
    }

    private var position: Int? { store.news.firstIndex { $0.id == item.id } }

    #if os(tvOS)
    private var tvBody: some View {
        ZStack(alignment: .top) {
            NL.bg.ignoresSafeArea()
            AuroraArt(story: item, animated: true)
                .frame(height: 520)
                .ignoresSafeArea()
                .opacity(0.9)
            HStack(alignment: .top, spacing: 70) {
                VStack(alignment: .leading, spacing: 26) {
                    StoryText(item: item, lang: store.lang, focused: $summaryFocused)
                    Spacer(minLength: 0)
                    HStack {
                        Text("Headline © \(item.sourceName ?? String(localized: "the publisher")). Summary by the Nordic Crypto team. Not investment advice.")
                        Spacer()
                        if let position {
                            Text(verbatim: "‹  \(position + 1) / \(store.news.count)  ›")
                                .monospacedDigit()
                        }
                    }
                    .font(NLFont.caption)
                    .foregroundStyle(NL.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, NLMetrics.margin)
            .padding(.top, 160)
            .padding(.bottom, 60)
        }
        .onAppear { summaryFocused = true }
        .onMoveCommand { direction in
            guard let position else { return }
            let next = direction == .left ? position - 1 : direction == .right ? position + 1 : position
            guard next != position, store.news.indices.contains(next) else { return }
            withAnimation(.smooth) { item = store.news[next] }
        }
    }
    #endif

    #if !os(tvOS)
    private var standardBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AuroraArt(story: item, animated: isVision)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: NLMetrics.cardRadius, style: .continuous))
                    .padding(.horizontal, NLMetrics.margin)
                StoryText(item: item, lang: store.lang, focused: $summaryFocused)
                    .padding(NLMetrics.margin)
                    .frame(maxWidth: 720, alignment: .leading)
                    .padding(.top, -90)
                Text("Headline © \(item.sourceName ?? String(localized: "the publisher")). Summary by the Nordic Crypto team. Not investment advice.")
                    .font(NLFont.caption)
                    .foregroundStyle(NL.textTertiary)
                    .padding(.horizontal, NLMetrics.margin)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
        }
        .background(NLBackground())
        .navigationTitle(item.sourceName ?? "")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .safeAreaInset(edge: .bottom) {
            if let url = item.url { SourceActions(url: url, source: item.sourceName) }
        }
    }

    private var isVision: Bool {
        #if os(visionOS)
        true
        #else
        false
        #endif
    }
    #endif
}

private struct StoryText: View {
    let item: NewsItem
    let lang: String
    var focused: FocusState<Bool>.Binding
    @Environment(FeedStore.self) private var store

    private var logoSize: CGFloat {
        #if os(tvOS)
        44
        #else
        28
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                CountryChip(code: item.country)
                SourceLogo(name: item.sourceName, url: store.logo(for: item), size: logoSize)
                Text(verbatim: [item.sourceName, item.published.map { Formats.dayTime($0, lang: lang) }].compactMap { $0 }.joined(separator: " · "))
                    .font(NLFont.kicker)
                    .foregroundStyle(NL.textSecondary)
            }
            Text(item.headline(for: lang))
                .font(NLFont.display)
                .foregroundStyle(NL.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let original = item.originalHeadline(for: lang) {
                Text(original)
                    .font(NLFont.body).italic()
                    .foregroundStyle(NL.textSecondary)
            }
            if let summary = item.summary(for: lang) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Nordic Crypto summary")
                        .font(NLFont.kicker)
                        .foregroundStyle(NL.accent)
                    Text(summary)
                        .font(NLFont.body)
                        .lineSpacing(4)
                        .foregroundStyle(NL.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(NLMetrics.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .nlGlass()
                .overlay(alignment: .leading) {
                    Capsule().fill(NL.accent).frame(width: 4).padding(.vertical, NLMetrics.cardPadding)
                }
                #if os(tvOS)
                // Something must hold focus so Menu goes back.
                .focusable()
                .focused(focused)
                #endif
            }
            HStack(spacing: 8) {
                ForEach(item.topics, id: \.self) { TopicChip(topic: $0) }
            }
            if item.paywall {
                Label("The source may require a subscription", systemImage: "lock.fill")
                    .font(NLFont.caption)
                    .foregroundStyle(NL.warning)
            }
        }
    }
}

#if !os(tvOS)
/// Read at the source, share, copy.
private struct SourceActions: View {
    let url: URL
    let source: String?

    var body: some View {
        HStack(spacing: 12) {
            Link(destination: url) {
                Label(source.map { String(localized: "Read at \($0)") } ?? String(localized: "Open event page"),
                      systemImage: "safari")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            ShareLink(item: url) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(.horizontal, NLMetrics.margin)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
#endif

// MARK: - Event

struct EventDetailView: View {
    let event: EventItem
    @Environment(FeedStore.self) private var store
    @FocusState private var focused: Bool

    var body: some View {
        #if os(tvOS)
        ZStack(alignment: .top) {
            NL.bg.ignoresSafeArea()
            AuroraArt(seed: event.id, primary: NL.country(event.country), secondary: NL.countryPartner(event.country))
                .frame(height: 460)
                .ignoresSafeArea()
            HStack(alignment: .top, spacing: 70) {
                info.frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, NLMetrics.margin)
            .padding(.top, 160)
        }
        .onAppear { focused = true }
        #else
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AuroraArt(seed: event.id, primary: NL.country(event.country), secondary: NL.countryPartner(event.country))
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: NLMetrics.cardRadius, style: .continuous))
                    .padding(.horizontal, NLMetrics.margin)
                info
                    .padding(NLMetrics.margin)
                    .frame(maxWidth: 720, alignment: .leading)
                    .padding(.top, -70)
            }
            .frame(maxWidth: .infinity)
        }
        .background(NLBackground())
        .navigationTitle(event.city ?? "")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .safeAreaInset(edge: .bottom) {
            if let url = event.url { SourceActions(url: url, source: nil) }
        }
        #endif
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .center, spacing: 18) {
                DateTile(date: event.start, country: event.country, lang: store.lang)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        CountryChip(code: event.country)
                        EntryBadge(event: event)
                        if event.past {
                            Text("Past event").font(NLFont.caption).foregroundStyle(NL.textTertiary)
                        }
                    }
                    Text(event.title)
                        .font(NLFont.display)
                        .foregroundStyle(NL.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let original = event.titleOriginal {
                Text(original).font(NLFont.body).italic().foregroundStyle(NL.textSecondary)
            }
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 24, verticalSpacing: 14) {
                InfoRow(label: "When", value: whenText)
                InfoRow(label: "Where", value: event.online ? String(localized: "Online") : (event.place ?? event.city ?? ""))
                if let organiser = event.organiser { InfoRow(label: "Organiser", value: organiser) }
                if let sponsor = event.sponsored, !sponsor.isEmpty { InfoRow(label: "Sponsor", value: sponsor) }
                if let note = event.note(for: store.lang) { InfoRow(label: "Note", value: note) }
            }
            .padding(NLMetrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .nlGlass()
            #if os(tvOS)
            .focusable()
            .focused($focused)
            #endif
        }
    }

    private var whenText: String {
        let start = Formats.dayTime(event.start, lang: store.lang)
        guard let end = event.end else { return start }
        let sameDay = event.start.map { Calendar.current.isDate($0, inSameDayAs: end) } ?? false
        return "\(start) – \(sameDay ? Formats.time(end, lang: store.lang) : Formats.dayTime(end, lang: store.lang))"
    }
}

private struct InfoRow: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        GridRow {
            Text(label)
                .font(NLFont.kicker)
                .foregroundStyle(NL.textTertiary)
            Text(value)
                .font(NLFont.body)
                .foregroundStyle(NL.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
