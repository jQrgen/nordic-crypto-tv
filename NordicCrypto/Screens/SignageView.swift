#if os(tvOS)
import SwiftUI

/// Apple TV runs as an information screen: one dashboard whose modules stay
/// in place while each one rotates its own content, so the viewer never loses
/// context. Nothing is navigable; the remote only switches the radio
/// (Play/Pause or a click).
struct SignageView: View {
    @Environment(FeedStore.self) private var store
    @Environment(Radio.self) private var radio
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 20) {
            DashboardHeader()
            HStack(alignment: .top, spacing: 22) {
                LeadModule()
                    .frame(maxWidth: .infinity)
                EventsModule()
                    .frame(width: 640)
            }
            .frame(height: 430)
            CountriesModule()
                .frame(height: 160)
            HStack(alignment: .top, spacing: 22) {
                LatestModule()
                    .frame(maxWidth: .infinity)
                NewsletterModule()
                    .frame(width: 640)
            }
            .frame(maxHeight: .infinity)
            DashboardFooter()
        }
        .padding(.horizontal, 56)
        .padding(.vertical, 30)
        .frame(width: 1920, height: 1080)
        .background(NLBackground())
        .ignoresSafeArea()
        // One invisible focus target, so the remote's buttons reach us.
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { focused = true }
        .onPlayPauseCommand { radio.toggle() }
        .onTapGesture { radio.toggle() }
    }
}

// MARK: - Rotation

/// Shows one page of `items` at a time and moves on every `interval`
/// seconds. Stateless: the page comes from the clock, so modules with
/// different offsets change at different moments.
private struct Rotating<Item, Content: View>: View {
    let items: [Item]
    var interval: Double
    var offset: Double = 0
    @ViewBuilder var content: (Item, Int) -> Content

    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let tick = Int((context.date.timeIntervalSinceReferenceDate + offset) / interval)
                let index = Self.freeze ?? (tick % items.count)
                ZStack {
                    content(items[index], index)
                        .id(index)
                        .transition(.opacity)
                }
                .animation(.easeInOut(duration: 0.9), value: index)
            }
        }
    }

    /// `-NCFreeze` keeps every module on its first page, for screenshots.
    static var freeze: Int? {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-NCFreeze") ? 0 : nil
        #else
        nil
        #endif
    }
}

/// Page marker for a rotating module.
private struct PageDots: View {
    let count: Int
    let index: Int

    var body: some View {
        if count > 1 {
            HStack(spacing: 6) {
                ForEach(0..<count, id: \.self) { i in
                    Capsule()
                        .fill(i == index ? NL.accent : NL.textTertiary.opacity(0.4))
                        .frame(width: i == index ? 22 : 8, height: 8)
                }
            }
            .animation(.smooth, value: index)
            .accessibilityHidden(true)
        }
    }
}

private struct ModuleHeader: View {
    let title: LocalizedStringKey
    var count: Int? = nil
    var pages: Int = 1
    var page: Int = 0

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(NL.textSecondary)
            if let count {
                Text(count, format: .number)
                    .font(.system(size: 24, weight: .regular, design: .rounded))
                    .foregroundStyle(NL.textTertiary)
            }
            Spacer()
            PageDots(count: pages, index: page)
        }
    }
}

extension View {
    fileprivate func module(padding: CGFloat = 20) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(NL.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(NL.hairline))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

// MARK: - Header and footer

private struct DashboardHeader: View {
    @Environment(FeedStore.self) private var store

    var body: some View {
        HStack(alignment: .center, spacing: 28) {
            Wordmark(size: 40)
            StatusPill(store: store)
            Text("\(store.news.count) stories · \(store.upcomingEvents.count) upcoming events")
                .font(NLFont.caption)
                .foregroundStyle(NL.textTertiary)
            Spacer()
            RadioPill()
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(context.date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Formats.locale(store.lang))))
                        .font(NLFont.kicker)
                        .foregroundStyle(NL.textSecondary)
                    Text(Formats.time(context.date, lang: store.lang))
                        .font(NLFont.rounded(40))
                        .monospacedDigit()
                        .foregroundStyle(NL.textPrimary)
                }
            }
        }
    }
}

/// Radio status, with the hint that the remote's Play/Pause controls it.
private struct RadioPill: View {
    @Environment(Radio.self) private var radio

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: radio.isOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .symbolEffect(.variableColor.iterative, isActive: radio.isPlaying)
                .foregroundStyle(radio.isOn ? NL.accent : NL.textTertiary)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: Radio.name)
                    .font(NLFont.kicker)
                    .foregroundStyle(NL.textPrimary)
                Text(radio.isOn ? "Press ⏯ to turn off" : "Press ⏯ to turn on")
                    .font(NLFont.caption)
                    .foregroundStyle(NL.textTertiary)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .background(NL.surface.opacity(0.8), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("radio")
        .accessibilityValue(Text(radio.isOn ? "On" : "Off"))
    }
}

private struct DashboardFooter: View {
    @Environment(FeedStore.self) private var store

    var body: some View {
        HStack(spacing: 18) {
            Text("Top topics")
                .font(NLFont.caption.weight(.semibold))
                .foregroundStyle(NL.textSecondary)
            ForEach(store.topTopics.prefix(7), id: \.topic) { entry in
                HStack(spacing: 6) {
                    TopicChip(topic: entry.topic)
                    Text(entry.count, format: .number)
                        .font(NLFont.caption)
                        .monospacedDigit()
                        .foregroundStyle(NL.textTertiary)
                }
            }
            Spacer(minLength: 20)
            Text("Not investment advice")
                .font(NLFont.caption)
                .foregroundStyle(NL.textTertiary)
                .lineLimit(1)
        }
    }
}

// MARK: - Modules

/// The five newest stories, one at a time, with summary and a QR code.
private struct LeadModule: View {
    @Environment(FeedStore.self) private var store

    var body: some View {
        let top = Array(store.news.prefix(5))
        Rotating(items: top, interval: 15) { item, index in
            ZStack(alignment: .bottomLeading) {
                AuroraArt(story: item, animated: true)
                HStack(alignment: .bottom, spacing: 28) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Kicker(item: item, lang: store.lang)
                            Spacer()
                            PageDots(count: top.count, index: index)
                        }
                        Text(item.headline(for: store.lang))
                            .font(.system(size: 54, weight: .bold, design: .serif))
                            .foregroundStyle(NL.textPrimary)
                            .lineLimit(3)
                            .minimumScaleFactor(0.8)
                        if let original = item.originalHeadline(for: store.lang) {
                            Text(original)
                                .font(.system(size: 25)).italic()
                                .foregroundStyle(NL.textSecondary)
                                .lineLimit(1)
                        }
                        if let summary = item.summary(for: store.lang) {
                            Text(summary)
                                .font(.system(size: 28))
                                .foregroundStyle(NL.textPrimary.opacity(0.88))
                                .lineLimit(3)
                        }
                        HStack(spacing: 8) {
                            ForEach(item.topics.prefix(3), id: \.self) { TopicChip(topic: $0) }
                        }
                    }
                    if let url = item.url {
                        VStack(spacing: 8) {
                            QRCodeImage(url: url)
                                .frame(width: 140, height: 140)
                                .padding(12)
                                .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            Text(verbatim: url.host() ?? "")
                                .font(.system(size: 17))
                                .foregroundStyle(NL.textTertiary)
                                .lineLimit(1)
                        }
                        .frame(width: 170)
                        .accessibilityHidden(true)
                    }
                }
                .padding(32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

/// Upcoming events, five per page.
private struct EventsModule: View {
    @Environment(FeedStore.self) private var store

    var body: some View {
        let pages = store.upcomingEvents.chunked(5)
        Rotating(items: pages, interval: 20, offset: 7) { page, index in
            VStack(alignment: .leading, spacing: 8) {
                ModuleHeader(title: "Coming up", count: store.upcomingEvents.count, pages: pages.count, page: index)
                ForEach(Array(page.enumerated()), id: \.offset) { _, event in
                    HStack(alignment: .center, spacing: 16) {
                        CompactDate(date: event.start, country: event.country, lang: store.lang)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.system(size: 25, weight: .semibold, design: .serif))
                                .foregroundStyle(NL.textPrimary)
                                .lineLimit(1)
                            Text(verbatim: [event.online ? String(localized: "Online") : event.city,
                                            Formats.time(event.start, lang: store.lang), event.organiser]
                                .compactMap { $0 }.joined(separator: " · "))
                                .font(.system(size: 18))
                                .foregroundStyle(NL.textTertiary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        CountryChip(code: event.country)
                    }
                }
            }
        }
        .module()
        .overlay {
            if store.upcomingEvents.isEmpty {
                Text("No upcoming events").font(NLFont.body).foregroundStyle(NL.textTertiary)
            }
        }
    }
}

private struct CompactDate: View {
    let date: Date?
    let country: String?
    let lang: String

    var body: some View {
        VStack(spacing: -2) {
            Text(date.map { Formats.dayNumber($0, lang: lang) } ?? "–")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(NL.textPrimary)
            Text(date.map { $0.formatted(.dateTime.month(.abbreviated).locale(Formats.locale(lang))) } ?? "")
                .font(.system(size: 15, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(NL.country(country))
        }
        .frame(width: 62, height: 56)
        .background(NL.country(country).opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// One cell per country; each cell rotates through its own headlines at a
/// different moment, so the row is always moving but never all at once.
private struct CountriesModule: View {
    var body: some View {
        HStack(spacing: 18) {
            ForEach(Array(Country.allCases.enumerated()), id: \.element) { i, country in
                CountryCell(country: country, offset: Double(i) * 2.2)
            }
        }
    }
}

private struct CountryCell: View {
    let country: Country
    let offset: Double
    @Environment(FeedStore.self) private var store

    var body: some View {
        let items = store.news(in: country)
        HStack(spacing: 16) {
            Capsule().fill(NL.country(country.rawValue)).frame(width: 5)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(country.name)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(NL.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(items.count, format: .number)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(items.isEmpty ? NL.textTertiary : NL.textPrimary)
                }
                if items.isEmpty {
                    Text("Quiet in \(country.name) — no stories this week")
                        .font(.system(size: 19))
                        .foregroundStyle(NL.textTertiary)
                } else {
                    Rotating(items: items, interval: 11, offset: offset) { item, _ in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                SourceLogo(name: item.sourceName, url: store.logo(for: item), size: 24)
                                Text(verbatim: [item.sourceName, Formats.stamp(item.published, lang: store.lang)].compactMap { $0 }.joined(separator: " · "))
                                    .font(.system(size: 16))
                                    .foregroundStyle(NL.textTertiary)
                                    .lineLimit(1)
                            }
                            Text(item.headline(for: store.lang))
                                .font(.system(size: 22, weight: .semibold, design: .serif))
                                .foregroundStyle(NL.textPrimary)
                                .lineLimit(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .module(padding: 20)
    }
}

/// Everything after the lead stories, six headlines per page.
private struct LatestModule: View {
    @Environment(FeedStore.self) private var store

    var body: some View {
        let pages = Array(store.news.dropFirst(5)).chunked(4)
        Rotating(items: pages, interval: 14, offset: 3) { page, index in
            VStack(alignment: .leading, spacing: 10) {
                ModuleHeader(title: "Latest", count: max(store.news.count - 5, 0), pages: pages.count, page: index)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 28), GridItem(.flexible(), spacing: 28)],
                          alignment: .leading, spacing: 12) {
                    ForEach(Array(page.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 12) {
                            Capsule().fill(NL.country(item.country)).frame(width: 4)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    SourceLogo(name: item.sourceName, url: store.logo(for: item), size: 24)
                                    Text(verbatim: [item.country, item.sourceName, Formats.stamp(item.published, lang: store.lang)]
                                        .compactMap { $0 }.joined(separator: " · "))
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(NL.textTertiary)
                                        .lineLimit(1)
                                }
                                Text(item.headline(for: store.lang))
                                    .font(.system(size: 22, weight: .semibold, design: .serif))
                                    .foregroundStyle(NL.textPrimary)
                                    .lineLimit(2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .module()
    }
}

private struct NewsletterModule: View {
    @Environment(FeedStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ModuleHeader(title: "Newsletter")
            if let latest = store.issues.first {
                let issue = store.issue(latest.id) ?? latest
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verbatim: "No. \(issue.number ?? 0) · \(issue.date.flatMap(NewsletterCard.parse).map { Formats.day($0, lang: store.lang) } ?? "")")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(NL.accent2)
                        Text(issue.title(for: store.lang))
                            .font(.system(size: 25, weight: .semibold, design: .serif))
                            .foregroundStyle(NL.textPrimary)
                            .lineLimit(3)
                        HStack(spacing: 14) {
                            if let n = issue.stories { Text("\(n) stories") }
                            if let n = issue.events { Text("\(n) events") }
                        }
                        .font(.system(size: 17))
                        .foregroundStyle(NL.textTertiary)
                    }
                    Spacer(minLength: 0)
                    VStack(spacing: 6) {
                        QRCodeImage(url: APIConfig.subscribe)
                            .frame(width: 112, height: 112)
                            .padding(10)
                            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        Text("Scan to subscribe")
                            .font(.system(size: 15))
                            .foregroundStyle(NL.textTertiary)
                    }
                    .accessibilityHidden(true)
                }
            }
        }
        .module()
        .background {
            AuroraArt.newsletter(seed: "newsletter")
                .opacity(0.35)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
    }
}

extension Array {
    /// Pages of `size`; the last page is topped up from the start so every
    /// page is full and the module never shows a half-empty panel.
    fileprivate func chunked(_ size: Int) -> [[Element]] {
        guard count > size else { return isEmpty ? [] : [self] }
        let pages = (count + size - 1) / size
        return (0..<pages).map { page in (0..<size).map { self[(page * size + $0) % count] } }
    }
}
#endif
