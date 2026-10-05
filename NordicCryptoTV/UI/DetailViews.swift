import SwiftUI
import AVKit

struct StoryDetailView: View {
    let item: NewsItem
    let lang: String
    @FocusState private var summaryFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 70) {
            VStack(alignment: .leading, spacing: 28) {
                MetaLine(item: item, lang: lang, size: 28)
                Text(item.headline(for: lang))
                    .font(.system(size: 66, weight: .bold))
                    .foregroundStyle(Theme.headline)
                    .lineLimit(4)
                    .minimumScaleFactor(0.7)
                if let original = item.originalHeadline(for: lang) {
                    Text(original)
                        .font(.system(size: 30)).italic()
                        .foregroundStyle(Theme.muted)
                }
                if let summary = item.summary(for: lang) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Nordic Crypto summary")
                            .font(Theme.mono(22, .bold)).foregroundStyle(Theme.amber)
                            .textCase(.uppercase)
                        Text(summary)
                            .font(.system(size: 38))
                            .foregroundStyle(Theme.body)
                            .lineSpacing(6)
                    }
                    .padding(32)
                    .background(Theme.panel, ignoresSafeAreaEdges: [])
                    .overlay(alignment: .leading) { Rectangle().fill(Theme.amber).frame(width: 6) }
                    // Something must hold focus so Menu dismisses the cover.
                    .focusable()
                    .focused($summaryFocused)
                }
                HStack(spacing: 12) {
                    ForEach(item.topics, id: \.self) { TopicTag(topic: $0) }
                }
                Spacer()
                Text("Headline © \(item.sourceName ?? String(localized: "the publisher")). Summary by the Nordic Crypto team. Not investment advice.")
                    .font(Theme.mono(20)).foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let url = item.url {
                SourceQR(url: url, caption: "Scan to read the full story", detail: item.paywall ? "Paywall" : nil)
            }
        }
        .padding(.horizontal, 90)
        .padding(.vertical, 70)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.background.ignoresSafeArea())
        .onAppear { summaryFocused = true }
    }
}

struct EventDetailView: View {
    let event: EventItem
    let lang: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 70) {
            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 16) {
                    CountryTag(code: event.country, size: 28)
                    PriceBadge(event: event)
                    if event.past {
                        Text("Past event").font(Theme.mono(24, .bold)).foregroundStyle(Theme.muted)
                            .textCase(.uppercase)
                    }
                }
                Text(event.title)
                    .font(.system(size: 62, weight: .bold)).foregroundStyle(Theme.headline)
                    .lineLimit(4).minimumScaleFactor(0.7)
                if let original = event.titleOriginal {
                    Text(original).font(.system(size: 30)).italic().foregroundStyle(Theme.muted)
                }
                VStack(alignment: .leading, spacing: 18) {
                    InfoRow(label: "When", value: whenText)
                    InfoRow(label: "Where", value: event.online ? String(localized: "Online") : (event.place ?? event.city ?? ""))
                    if let organiser = event.organiser { InfoRow(label: "Organiser", value: organiser) }
                    if let sponsor = event.sponsored, !sponsor.isEmpty { InfoRow(label: "Sponsor", value: sponsor) }
                    if let note = event.note(for: lang) { InfoRow(label: "Note", value: note) }
                }
                .padding(32)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.panel, ignoresSafeAreaEdges: [])
                .overlay(alignment: .leading) { Rectangle().fill(Theme.amber).frame(width: 6) }
                .focusable()
                .focused($focused)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let url = event.url {
                SourceQR(url: url, caption: "Scan for tickets and details", detail: nil)
            }
        }
        .padding(.horizontal, 90)
        .padding(.vertical, 70)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.background.ignoresSafeArea())
        .onAppear { focused = true }
    }

    private var whenText: String {
        let start = Formats.dayTime(event.start, lang: lang)
        guard let end = event.end else { return start }
        return "\(start) – \(Formats.dayTime(end, lang: lang))"
    }
}

private struct InfoRow: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 24) {
            Text(label).font(Theme.mono(24, .bold)).foregroundStyle(Theme.amber)
                .textCase(.uppercase)
                .frame(width: 220, alignment: .leading)
            Text(value).font(.system(size: 32)).foregroundStyle(Theme.body)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SourceQR: View {
    let url: URL
    let caption: LocalizedStringKey
    let detail: LocalizedStringKey?

    var body: some View {
        VStack(spacing: 18) {
            QRCodeView(url: url).frame(width: 380, height: 380)
            Text(caption)
                .font(Theme.mono(22, .bold)).foregroundStyle(Theme.headline)
                .multilineTextAlignment(.center)
            Text(url.host() ?? "")
                .font(Theme.mono(22)).foregroundStyle(Theme.amber)
            if let detail {
                Text(detail).font(Theme.mono(20, .bold)).foregroundStyle(Theme.alert).textCase(.uppercase)
            }
        }
        .frame(width: 400)
    }
}

/// System player, so the Siri Remote transport controls work as expected.
struct NewsreelPlayer: UIViewControllerRepresentable {
    let url: URL
    var title: String

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        // GitHub release assets are served as application/octet-stream.
        let asset = AVURLAsset(url: url, options: [AVURLAssetOverrideMIMETypeKey: "video/mp4"])
        let item = AVPlayerItem(asset: asset)
        let titleItem = AVMutableMetadataItem()
        titleItem.identifier = .commonIdentifierTitle
        titleItem.value = title as NSString
        titleItem.extendedLanguageTag = "und"
        item.externalMetadata = [titleItem]
        let controller = AVPlayerViewController()
        controller.player = AVPlayer(playerItem: item)
        controller.player?.play()
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {}

    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: ()) {
        controller.player?.pause()
    }
}
