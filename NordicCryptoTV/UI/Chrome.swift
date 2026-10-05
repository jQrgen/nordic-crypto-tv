import SwiftUI

enum Screen: String, CaseIterable, Identifiable {
    case top, nordics, events, brief
    var id: String { rawValue }

    var key: String {
        switch self {
        case .top: "F1"
        case .nordics: "F2"
        case .events: "F3"
        case .brief: "F4"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .top: "Top news"
        case .nordics: "Nordics"
        case .events: "Events"
        case .brief: "Newsletter"
        }
    }
}

/// Wordmark, function keys and Nordic world clocks.
struct HeaderBar: View {
    @Binding var screen: Screen
    @FocusState private var focusedKey: Screen?

    var body: some View {
        HStack(spacing: 28) {
            HStack(spacing: 0) {
                Text("NC")
                    .font(Theme.mono(34, .heavy))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Theme.amber, ignoresSafeAreaEdges: [])
                Text("NORDIC CRYPTO")
                    .font(Theme.mono(34, .heavy))
                    .foregroundStyle(Theme.amber)
                    .padding(.horizontal, 16)
            }
            .fixedSize()
            .accessibilityElement(children: .combine)

            HStack(spacing: 12) {
                ForEach(Screen.allCases) { s in
                    Button { screen = s } label: {
                        HStack(spacing: 10) {
                            Text(s.key).font(Theme.mono(22, .bold))
                                .foregroundStyle(s == screen ? .black : Theme.amber)
                            Text(s.title).font(Theme.mono(24, .bold)).textCase(.uppercase)
                                .foregroundStyle(s == screen ? .black : Theme.headline)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(s == screen ? Theme.amber : Theme.panel, ignoresSafeAreaEdges: [])
                        .overlay(Rectangle().stroke(focusedKey == s ? Color.white : Theme.rule,
                                                    lineWidth: focusedKey == s ? 3 : 1))
                        .scaleEffect(focusedKey == s ? 1.06 : 1)
                        .animation(.easeOut(duration: 0.15), value: focusedKey)
                    }
                    .buttonStyle(.plain)
                    .focused($focusedKey, equals: s)
                }
            }
            .focusSection()
            .defaultFocus($focusedKey, screen)
            .onChange(of: focusedKey) { old, new in
                // Like a tab bar: moving focus sideways across the keys switches
                // screens. Focus arriving from the content below does not.
                if let new, old != nil { screen = new }
            }

            Spacer(minLength: 0)
            WorldClocks()
        }
    }
}

struct WorldClocks: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 22) {
                ForEach([Country.no, .se, .fi, .is]) { c in
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(c.capital.prefix(3))
                            .font(Theme.mono(18, .bold)).foregroundStyle(Theme.amber)
                        Text(Self.clock(context.date, in: c.timeZone))
                            .font(Theme.mono(26, .semibold)).foregroundStyle(Theme.headline)
                            .monospacedDigit()
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    static func clock(_ date: Date, in zone: TimeZone) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        let c = cal.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}

struct StatusStrip: View {
    let store: FeedStore

    var body: some View {
        HStack(spacing: 18) {
            switch store.status {
            case .live:
                Circle().fill(Theme.live).frame(width: 14, height: 14)
                Text("LIVE").font(Theme.mono(20, .bold)).foregroundStyle(Theme.live)
            case .loading:
                ProgressView().scaleEffect(0.6)
                Text("CONNECTING").font(Theme.mono(20, .bold)).foregroundStyle(Theme.muted)
            case .offline:
                Circle().fill(Theme.alert).frame(width: 14, height: 14)
                Text("OFFLINE · SAVED EDITION").font(Theme.mono(20, .bold)).foregroundStyle(Theme.alert)
            }
            if let updated = store.updated {
                Text("Updated \(Formats.dayTime(updated, lang: store.lang))")
                    .font(Theme.mono(20)).foregroundStyle(Theme.muted)
            }
            Spacer()
            Text("\(store.news.count) STORIES · \(store.upcomingEvents.count) EVENTS · NO SE DK FI IS")
                .font(Theme.mono(20)).foregroundStyle(Theme.muted)
            Text("Not investment advice")
                .font(Theme.mono(20)).foregroundStyle(Theme.amberDim)
                .textCase(.uppercase)
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
    }
}

/// Endless headline crawl along the bottom of the screen.
struct TickerTape: View {
    let items: [NewsItem]
    let lang: String
    var pointsPerSecond: Double = 90

    @State private var contentWidth: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            Text("NEWS")
                .font(Theme.mono(24, .heavy))
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .frame(maxHeight: .infinity)
                .background(Theme.amber, ignoresSafeAreaEdges: [])
            GeometryReader { _ in
                TimelineView(.animation(paused: reduceMotion)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let offset = CGFloat((t * pointsPerSecond).truncatingRemainder(dividingBy: Double(contentWidth)))
                    HStack(spacing: 0) {
                        strip
                        strip
                    }
                    .fixedSize()
                    .offset(x: -offset)
                }
                .frame(maxHeight: .infinity, alignment: .leading)
            }
            .clipped()
        }
        .frame(height: 54)
        .background(Theme.panel, ignoresSafeAreaEdges: [])
        .overlay(alignment: .top) { Rectangle().fill(Theme.amber).frame(height: 2) }
        .accessibilityHidden(true)
    }

    private var strip: some View {
        HStack(spacing: 0) {
            ForEach(items.prefix(20)) { item in
                HStack(spacing: 12) {
                    Text(item.country ?? "")
                        .font(Theme.mono(22, .heavy))
                        .foregroundStyle(Theme.amber)
                    Text(item.headline(for: lang))
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Theme.headline)
                    Text("■").font(.system(size: 14)).foregroundStyle(Theme.amberDim)
                        .padding(.horizontal, 22)
                }
            }
        }
        .fixedSize()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { contentWidth = max($0, 1) }
    }
}
