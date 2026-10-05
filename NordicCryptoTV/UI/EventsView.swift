import SwiftUI

struct EventsView: View {
    let store: FeedStore
    @Environment(Router.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "Upcoming events", trailing: "\(store.upcomingEvents.count)")
                EventTableHeader()
                if store.upcomingEvents.isEmpty {
                    Text("No upcoming events")
                        .font(Theme.mono(24)).foregroundStyle(Theme.muted).padding(24)
                }
                ForEach(store.upcomingEvents) { event in
                    EventRow(event: event, lang: store.lang) { router.event = event }
                }
                if !store.pastEvents.isEmpty {
                    SectionLabel(text: "Past events", trailing: "\(store.pastEvents.count)")
                        .padding(.top, 30)
                    ForEach(store.pastEvents) { event in
                        EventRow(event: event, lang: store.lang) { router.event = event }
                            .opacity(0.6)
                    }
                }
            }
            .padding(.vertical, 24)
        }
        .scrollClipDisabled()
    }
}

private enum Col {
    static let date: CGFloat = 230
    static let cc: CGFloat = 80
    static let city: CGFloat = 250
    static let organiser: CGFloat = 400
    static let price: CGFloat = 150
}

struct EventTableHeader: View {
    var body: some View {
        HStack(spacing: 20) {
            Text("Date").frame(width: Col.date, alignment: .leading)
            Text("CC").frame(width: Col.cc, alignment: .leading)
            Text("City").frame(width: Col.city, alignment: .leading)
            Text("Event").frame(maxWidth: .infinity, alignment: .leading)
            Text("Organiser").frame(width: Col.organiser, alignment: .leading)
            Text("Entry").frame(width: Col.price, alignment: .leading)
        }
        .font(Theme.mono(20, .bold))
        .foregroundStyle(Theme.amber)
        .textCase(.uppercase)
        .padding(.horizontal, 20)
        .accessibilityHidden(true)
    }
}

struct EventRow: View {
    let event: EventItem
    let lang: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Text(Formats.dayTime(event.start, lang: lang))
                    .font(Theme.mono(22, .bold)).foregroundStyle(Theme.headline)
                    .frame(width: Col.date, alignment: .leading)
                CountryTag(code: event.country, size: 20)
                    .frame(width: Col.cc, alignment: .leading)
                Text(event.online ? String(localized: "Online") : (event.city ?? ""))
                    .font(Theme.mono(22)).foregroundStyle(Theme.body)
                    .lineLimit(1)
                    .frame(width: Col.city, alignment: .leading)
                Text(event.title)
                    .font(.system(size: 27, weight: .semibold)).foregroundStyle(Theme.headline)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(event.organiser ?? "")
                    .font(.system(size: 22)).foregroundStyle(Theme.muted)
                    .lineLimit(2)
                    .frame(width: Col.organiser, alignment: .leading)
                PriceBadge(event: event)
                    .frame(width: Col.price, alignment: .leading)
            }
        }
        .buttonStyle(TerminalButtonStyle(padding: 18))
    }
}

struct PriceBadge: View {
    let event: EventItem

    var body: some View {
        let (label, color): (LocalizedStringKey?, Color) = switch (event.sponsored != nil, event.paid) {
        case (true, _): ("Sponsored", Theme.link)
        case (_, true?): ("Paid", Theme.amber)
        case (_, false?): ("Free", Theme.live)
        default: (nil, Theme.muted)
        }
        if let label {
            Text(label)
                .font(Theme.mono(20, .bold))
                .textCase(.uppercase)
                .foregroundStyle(color)
        }
    }
}

struct EventCard: View {
    let event: EventItem
    let lang: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text(Formats.day(event.start, lang: lang))
                        .font(Theme.mono(30, .heavy)).foregroundStyle(Theme.amber)
                    CountryTag(code: event.country, size: 20)
                    Text(event.online ? String(localized: "Online") : (event.city ?? ""))
                        .font(Theme.mono(20)).foregroundStyle(Theme.muted).lineLimit(1)
                    Spacer()
                    PriceBadge(event: event)
                }
                Text(event.title)
                    .font(.system(size: 28, weight: .semibold)).foregroundStyle(Theme.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Text(event.organiser ?? "")
                    .font(.system(size: 21)).foregroundStyle(Theme.muted).lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        }
        .buttonStyle(TerminalButtonStyle(padding: 22))
    }
}
