import SwiftUI

@MainActor
@Observable
final class Router {
    var story: NewsItem?
    var event: EventItem?
    var reader: NewsletterIssue?
    var newsreel: Newsreel?
}

struct TopNewsView: View {
    let store: FeedStore
    @Environment(Router.self) private var router

    var body: some View {
        let news = store.news
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                HStack(alignment: .top, spacing: 36) {
                    VStack(alignment: .leading, spacing: 24) {
                        if let lead = news.first {
                            SectionLabel(text: "Lead story")
                            LeadStoryCard(item: lead, lang: store.lang) { router.story = lead }
                        }
                        HStack(alignment: .top, spacing: 24) {
                            ForEach(news.dropFirst().prefix(2)) { item in
                                StoryCard(item: item, lang: store.lang, lines: 3) { router.story = item }
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 14) {
                        SectionLabel(text: "Latest")
                        ForEach(Array(news.dropFirst(3).prefix(8).enumerated()), id: \.element.id) { i, item in
                            NumberedRow(rank: i + 1, item: item, lang: store.lang) { router.story = item }
                        }
                    }
                    .frame(width: 660)
                }

                TopicBoard(topics: store.topTopics, total: news.count)

                if !store.upcomingEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 18) {
                        SectionLabel(text: "Upcoming events")
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: 24) {
                                ForEach(store.upcomingEvents.prefix(8)) { event in
                                    EventCard(event: event, lang: store.lang) { router.event = event }
                                        .frame(width: 520)
                                }
                            }
                            .padding(.vertical, 20)
                        }
                        .scrollClipDisabled()
                    }
                }

                if news.count > 11 {
                    VStack(alignment: .leading, spacing: 18) {
                        SectionLabel(text: "More headlines", trailing: "\(news.count - 11)")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 24), count: 3), spacing: 24) {
                            ForEach(news.dropFirst(11)) { item in
                                StoryCard(item: item, lang: store.lang, lines: 3) { router.story = item }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 24)
        }
        .scrollClipDisabled()
    }
}

struct MetaLine: View {
    let item: NewsItem
    let lang: String
    var size: CGFloat = 22

    var body: some View {
        HStack(spacing: 14) {
            CountryTag(code: item.country, size: size)
            Text(item.sourceName?.uppercased() ?? "")
                .font(Theme.mono(size, .bold)).foregroundStyle(Theme.amber)
                .lineLimit(1)
            Text(Formats.stamp(item.published, lang: lang))
                .font(Theme.mono(size)).foregroundStyle(Theme.muted)
                .lineLimit(1)
            if item.paywall {
                Text("PAYWALL")
                    .font(Theme.mono(size - 4, .bold)).foregroundStyle(Theme.alert)
                    .padding(.horizontal, 6)
                    .overlay(Rectangle().stroke(Theme.alert, lineWidth: 1))
            }
        }
    }
}

struct LeadStoryCard: View {
    let item: NewsItem
    let lang: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 18) {
                MetaLine(item: item, lang: lang, size: 24)
                Text(item.headline(for: lang))
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(Theme.headline)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                if let original = item.originalHeadline(for: lang) {
                    Text(original)
                        .font(.system(size: 26, weight: .regular)).italic()
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                if let summary = item.summary(for: lang) {
                    Text(summary)
                        .font(.system(size: 31))
                        .foregroundStyle(Theme.body)
                        .lineLimit(4)
                }
                HStack(spacing: 10) {
                    ForEach(item.topics.prefix(4), id: \.self) { TopicTag(topic: $0) }
                }
            }
        }
        .buttonStyle(TerminalButtonStyle(padding: 32))
    }
}

struct StoryCard: View {
    let item: NewsItem
    let lang: String
    var lines: Int = 3
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                MetaLine(item: item, lang: lang, size: 20)
                Text(item.headline(for: lang))
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Theme.headline)
                    .lineLimit(lines)
                    .multilineTextAlignment(.leading)
                if let topic = item.topics.first { TopicTag(topic: topic) }
            }
            .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
        }
        .buttonStyle(TerminalButtonStyle(padding: 22))
    }
}

struct NumberedRow: View {
    let rank: Int
    let item: NewsItem
    let lang: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 16) {
                Text("\(rank)")
                    .font(Theme.mono(34, .heavy)).foregroundStyle(Theme.amber)
                    .frame(width: 44, alignment: .trailing)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text(item.country ?? "").font(Theme.mono(18, .bold)).foregroundStyle(Theme.countryColor(item.country).opacity(1))
                            .padding(.horizontal, 5).background(Color.white.opacity(0.92), ignoresSafeAreaEdges: [])
                        Text(Formats.stamp(item.published, lang: lang))
                            .font(Theme.mono(18)).foregroundStyle(Theme.muted)
                        Text(item.sourceName ?? "")
                            .font(Theme.mono(18)).foregroundStyle(Theme.muted).lineLimit(1)
                    }
                    Text(item.headline(for: lang))
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(Theme.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .buttonStyle(TerminalButtonStyle(padding: 12))
    }
}

/// Topic counts drawn as a market-board style bar list.
struct TopicBoard: View {
    let topics: [(topic: String, count: Int)]
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionLabel(text: "Top topics", trailing: "\(total)")
            let shown = Array(topics.prefix(8))
            let maxCount = max(shown.first?.count ?? 1, 1)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 48), GridItem(.flexible(), spacing: 48)], spacing: 14) {
                ForEach(shown, id: \.topic) { entry in
                    HStack(spacing: 16) {
                        Text(entry.topic.uppercased())
                            .font(Theme.mono(22, .bold)).foregroundStyle(Theme.headline)
                            .frame(width: 300, alignment: .leading)
                            .lineLimit(1)
                        GeometryReader { geo in
                            Rectangle().fill(Theme.amber)
                                .frame(width: geo.size.width * CGFloat(entry.count) / CGFloat(maxCount))
                        }
                        .frame(height: 18)
                        Text("\(entry.count)")
                            .font(Theme.mono(22, .bold)).foregroundStyle(Theme.amber)
                            .frame(width: 60, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(24)
            .background(Theme.panel, ignoresSafeAreaEdges: [])
            .overlay(Rectangle().stroke(Theme.rule, lineWidth: 1))
        }
    }
}
