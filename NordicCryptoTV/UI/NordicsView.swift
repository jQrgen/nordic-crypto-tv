import SwiftUI

/// One column per country, like a regional markets board.
struct NordicsView: View {
    let store: FeedStore
    @Environment(Router.self) private var router

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 20) {
                ForEach(Country.allCases) { country in
                    let items = store.news(in: country)
                    VStack(alignment: .leading, spacing: 14) {
                        CountryHeader(country: country, count: items.count)
                        if items.isEmpty {
                            Text("No stories yet")
                                .font(Theme.mono(22)).foregroundStyle(Theme.muted)
                                .frame(maxWidth: .infinity, minHeight: 120)
                                .background(Theme.panel, ignoresSafeAreaEdges: [])
                                .overlay(Rectangle().stroke(Theme.rule, style: StrokeStyle(lineWidth: 1, dash: [6])))
                        }
                        ForEach(items) { item in
                            CompactStoryRow(item: item, lang: store.lang) { router.story = item }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    .focusSection()
                }
            }
            .padding(.vertical, 24)
        }
        .scrollClipDisabled()
    }
}

struct CountryHeader: View {
    let country: Country
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                CountryTag(code: country.rawValue, size: 30)
                Spacer()
                Text("\(count)")
                    .font(Theme.mono(40, .heavy))
                    .foregroundStyle(count > 0 ? Theme.amber : Theme.muted)
            }
            Text(country.name.uppercased())
                .font(Theme.mono(24, .bold)).foregroundStyle(Theme.headline)
            TimelineView(.periodic(from: .now, by: 30)) { ctx in
                Text("\(country.capital) \(WorldClocks.clock(ctx.date, in: country.timeZone))")
                    .font(Theme.mono(18)).foregroundStyle(Theme.muted)
            }
            Rectangle().fill(Theme.countryColor(country.rawValue)).frame(height: 4)
        }
        .accessibilityElement(children: .combine)
    }
}

struct CompactStoryRow: View {
    let item: NewsItem
    let lang: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(Formats.day(item.published, lang: lang))
                        .font(Theme.mono(17, .bold)).foregroundStyle(Theme.amber)
                    Text(item.sourceName ?? "")
                        .font(Theme.mono(17)).foregroundStyle(Theme.muted).lineLimit(1)
                }
                Text(item.headline(for: lang))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Theme.headline)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(TerminalButtonStyle(padding: 14))
    }
}
