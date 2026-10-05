import SwiftUI

struct NewsletterView: View {
    let store: FeedStore
    @Environment(Router.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                if let latest = store.issues.first {
                    SectionLabel(text: "Latest issue")
                    IssueHero(issue: store.issue(latest.id) ?? latest, lang: store.lang)
                }
                if store.issues.count > 1 {
                    SectionLabel(text: "Archive", trailing: "\(store.issues.count)")
                    ForEach(store.issues.dropFirst()) { issue in
                        let full = store.issue(issue.id) ?? issue
                        Button { router.reader = full } label: {
                            HStack(spacing: 24) {
                                Text("#\(issue.number ?? 0)")
                                    .font(Theme.mono(34, .heavy)).foregroundStyle(Theme.amber)
                                    .frame(width: 110, alignment: .leading)
                                Text(issue.title(for: store.lang))
                                    .font(.system(size: 28, weight: .semibold)).foregroundStyle(Theme.headline)
                                    .lineLimit(2)
                                Spacer()
                                Text(issue.date ?? "").font(Theme.mono(22)).foregroundStyle(Theme.muted)
                            }
                        }
                        .buttonStyle(TerminalButtonStyle(padding: 20))
                    }
                }
                if store.issues.isEmpty {
                    Text("No issues yet").font(Theme.mono(24)).foregroundStyle(Theme.muted)
                }
            }
            .padding(.vertical, 24)
        }
        .scrollClipDisabled()
    }
}

struct IssueHero: View {
    let issue: NewsletterIssue
    let lang: String
    @Environment(Router.self) private var router

    var body: some View {
        HStack(alignment: .top, spacing: 40) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    Text("NO. \(issue.number ?? 0)")
                        .font(Theme.mono(26, .heavy)).foregroundStyle(.black)
                        .padding(.horizontal, 12).background(Theme.amber, ignoresSafeAreaEdges: [])
                    Text(issue.date ?? "").font(Theme.mono(24)).foregroundStyle(Theme.muted)
                }
                Text(issue.title(for: lang))
                    .font(.system(size: 52, weight: .bold)).foregroundStyle(Theme.headline)
                    .lineLimit(3)
                if let subtitle = issue.subtitle(for: lang) {
                    Text(subtitle).font(.system(size: 30)).foregroundStyle(Theme.body).lineLimit(4)
                }
                HStack(spacing: 30) {
                    if let n = issue.stories { Stat(value: "\(n)", label: "Stories") }
                    if let n = issue.events { Stat(value: "\(n)", label: "Events") }
                    if let d = issue.video?.durationSeconds {
                        Stat(value: String(format: "%d:%02d", d / 60, d % 60), label: "Newsreel")
                    }
                }
                HStack(spacing: 24) {
                    if let reel = issue.video, reel.playableURL != nil {
                        Button { router.newsreel = reel } label: {
                            Label("Watch newsreel", systemImage: "play.fill")
                                .font(Theme.mono(26, .bold))
                        }
                        .buttonStyle(TerminalButtonStyle(padding: 22))
                        .fixedSize()
                    }
                    if issue.text(for: lang) != nil {
                        Button { router.reader = issue } label: {
                            Label("Read issue", systemImage: "text.alignleft")
                                .font(Theme.mono(26, .bold))
                        }
                        .buttonStyle(TerminalButtonStyle(padding: 22))
                        .fixedSize()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let url = issue.htmlURL {
                VStack(spacing: 14) {
                    QRCodeView(url: url).frame(width: 300, height: 300)
                    Text("Scan to subscribe and read online")
                        .font(Theme.mono(20)).foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .frame(width: 300)
                }
            }
        }
        .padding(36)
        .background(Theme.panel, ignoresSafeAreaEdges: [])
        .overlay(Rectangle().stroke(Theme.rule, lineWidth: 1))
    }
}

struct Stat: View {
    let value: String
    let label: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(Theme.mono(44, .heavy)).foregroundStyle(Theme.amber)
            Text(label).font(Theme.mono(20, .bold)).foregroundStyle(Theme.muted).textCase(.uppercase)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Full-screen reader for a newsletter issue. Each paragraph takes focus so
/// the remote can scroll through long text.
struct IssueReader: View {
    let issue: NewsletterIssue
    let lang: String

    var body: some View {
        let paragraphs = (issue.text(for: lang) ?? "")
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(issue.title(for: lang))
                    .font(.system(size: 56, weight: .bold)).foregroundStyle(Theme.headline)
                    .padding(.bottom, 30)
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, p in
                    ReaderParagraph(text: p)
                }
            }
            .frame(maxWidth: 1300, alignment: .leading)
            .padding(.vertical, 60)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background.ignoresSafeArea())
    }
}

private struct ReaderParagraph: View {
    let text: String
    @FocusState private var focused: Bool

    var body: some View {
        // Short lines without a full stop are section and story headings.
        let isHeading = text.count < 110 && !text.contains("\n") && !text.hasSuffix(".")
        Text(text)
            .font(isHeading ? .system(size: 36, weight: .bold) : .system(size: 31))
            .foregroundStyle(isHeading ? Theme.amber : Theme.body)
            .lineSpacing(6)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(focused ? Theme.panelHi : .clear, ignoresSafeAreaEdges: [])
            .overlay(alignment: .leading) {
                Rectangle().fill(focused ? Theme.amber : .clear).frame(width: 5)
            }
            .focusable()
            .focused($focused)
    }
}
