import SwiftUI
import CoreImage.CIFilterBuiltins

/// Terminal look: black glass, amber keys, dense white type.
enum Theme {
    static let background = Color(red: 0.0, green: 0.0, blue: 0.0)
    static let panel = Color(red: 0.055, green: 0.063, blue: 0.082)
    static let panelHi = Color(red: 0.10, green: 0.11, blue: 0.14)
    static let rule = Color(white: 0.22)
    static let amber = Color(red: 0.984, green: 0.545, blue: 0.118)
    static let amberDim = Color(red: 0.55, green: 0.30, blue: 0.06)
    static let headline = Color.white
    static let body = Color(white: 0.82)
    static let muted = Color(white: 0.55)
    static let live = Color(red: 0.18, green: 0.80, blue: 0.36)
    static let alert = Color(red: 0.93, green: 0.23, blue: 0.21)
    static let link = Color(red: 0.36, green: 0.66, blue: 1.0)

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func countryColor(_ code: String?) -> Color {
        switch code {
        case "NO": Color(red: 0.86, green: 0.18, blue: 0.22)
        case "SE": Color(red: 0.0, green: 0.42, blue: 0.74)
        case "DK": Color(red: 0.78, green: 0.06, blue: 0.18)
        case "FI": Color(red: 0.0, green: 0.30, blue: 0.62)
        case "IS": Color(red: 0.0, green: 0.32, blue: 0.62)
        default: Color(white: 0.35)
        }
    }
}

/// Square-cornered card that lights up amber when focused.
struct TerminalButtonStyle: ButtonStyle {
    var padding: CGFloat = 0

    func makeBody(configuration: Configuration) -> some View {
        FocusBody(configuration: configuration, padding: padding)
    }

    private struct FocusBody: View {
        let configuration: Configuration
        let padding: CGFloat
        @Environment(\.isFocused) private var focused

        var body: some View {
            configuration.label
                .padding(padding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(focused ? Theme.panelHi : Theme.panel, ignoresSafeAreaEdges: [])
                .overlay(alignment: .leading) {
                    Rectangle().fill(focused ? Theme.amber : .clear).frame(width: 6)
                }
                .overlay(Rectangle().stroke(focused ? Theme.amber : Theme.rule, lineWidth: focused ? 3 : 1))
                .scaleEffect(configuration.isPressed ? 0.98 : (focused ? 1.02 : 1))
                .shadow(color: focused ? Theme.amber.opacity(0.25) : .clear, radius: 18)
                .animation(.easeOut(duration: 0.15), value: focused)
        }
    }
}

struct CountryTag: View {
    let code: String?
    var size: CGFloat = 22

    var body: some View {
        Text(code ?? "—")
            .font(Theme.mono(size, .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, size * 0.4)
            .padding(.vertical, size * 0.12)
            .background(Theme.countryColor(code), ignoresSafeAreaEdges: [])
    }
}

struct TopicTag: View {
    let topic: String

    var body: some View {
        Text(topic.uppercased())
            .font(Theme.mono(20, .medium))
            .foregroundStyle(Theme.amber)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .overlay(Rectangle().stroke(Theme.amberDim, lineWidth: 1))
    }
}

struct SectionLabel: View {
    let text: LocalizedStringKey
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            Rectangle().fill(Theme.amber).frame(width: 10, height: 26)
            Text(text).font(Theme.mono(26, .bold)).foregroundStyle(Theme.amber)
            Rectangle().fill(Theme.rule).frame(height: 1)
            if let trailing {
                Text(trailing).font(Theme.mono(22)).foregroundStyle(Theme.muted)
            }
        }
        .textCase(.uppercase)
    }
}

/// A QR code for a URL, since Apple TV has no web browser.
struct QRCodeView: View {
    let url: URL

    var body: some View {
        if let image = Self.image(for: url.absoluteString) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(18)
                .background(.white)
                .accessibilityLabel(Text("QR code for \(url.host() ?? url.absoluteString)"))
        }
    }

    static func image(for string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
              let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

enum Formats {
    /// 24-hour clock everywhere; plain English uses British conventions.
    static func locale(_ lang: String) -> Locale {
        Locale(identifier: lang == "en" ? "en_GB" : lang)
    }

    static func time(_ date: Date?, lang: String) -> String {
        guard let date else { return "--:--" }
        return date.formatted(.dateTime.hour().minute().locale(locale(lang)))
    }

    static func day(_ date: Date?, lang: String) -> String {
        guard let date else { return "" }
        return date.formatted(.dateTime.day().month(.abbreviated).locale(locale(lang))).uppercased()
    }

    static func dayTime(_ date: Date?, lang: String) -> String {
        guard let date else { return "" }
        return date.formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(locale(lang)))
    }

    /// Terminal-style stamp: the time for today's stories, else the date.
    static func stamp(_ date: Date?, lang: String) -> String {
        guard let date else { return "" }
        return Calendar.current.isDateInToday(date) ? time(date, lang: lang) : day(date, lang: lang)
    }
}
