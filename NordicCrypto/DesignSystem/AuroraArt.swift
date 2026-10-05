import SwiftUI

/// Generated "northern lights" art. News items have no images, so every story
/// gets its own mesh gradient from its country and topic colors, jittered by a
/// stable hash of its id so the same story always looks the same.
struct AuroraArt: View {
    let seed: String
    let primary: Color
    let secondary: Color
    var animated = false
    var scrim = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Group {
            if animated && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                    mesh(phase: context.date.timeIntervalSinceReferenceDate / 40 * 2 * .pi)
                }
            } else {
                mesh(phase: 0)
            }
        }
        .overlay {
            if scrim {
                LinearGradient(stops: [
                    .init(color: .clear, location: 0.35),
                    .init(color: NL.bg.opacity(contrast == .increased ? 0.95 : 0.88), location: 1),
                ], startPoint: .top, endPoint: .bottom)
            }
        }
        .accessibilityHidden(true)
    }

    private func mesh(phase: Double) -> some View {
        let h = Self.hash(seed)
        func j(_ shift: UInt64) -> Float { Float(Double((h >> shift) & 0xFF) / 255 - 0.5) * 0.3 }
        let drift = Float(sin(phase)) * 0.06
        let flip = (h & 1) == 1
        let a = flip ? secondary : primary
        let b = flip ? primary : secondary
        return MeshGradient(
            width: 3, height: 3,
            points: [
                [0, 0], [0.5 + j(8) + drift, 0], [1, 0],
                [0, 0.5 + j(16)], [0.5 + j(24) - drift, 0.45 + j(32) + drift], [1, 0.5 + j(40)],
                [0, 1], [0.5 + j(48), 1], [1, 1],
            ],
            colors: [
                NL.bg, a.opacity(0.75), b.opacity(0.45),
                b.opacity(0.55), a.opacity(0.9), NL.bg,
                NL.bg, b.opacity(0.4), a.opacity(0.35),
            ],
            smoothsColors: true
        )
        .background(NL.bg)
    }

    /// FNV-1a; Swift's `hashValue` changes per launch.
    static func hash(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for byte in s.utf8 { h = (h ^ UInt64(byte)) &* 0x100000001b3 }
        return h
    }
}

extension AuroraArt {
    init(story: NewsItem, animated: Bool = false, scrim: Bool = true) {
        self.init(seed: story.id, primary: NL.country(story.country), secondary: NL.topic(story.topics.first),
                  animated: animated, scrim: scrim)
    }

    init(country code: String, animated: Bool = false) {
        self.init(seed: code, primary: NL.country(code), secondary: NL.countryPartner(code), animated: animated)
    }

    static func newsletter(seed: String, animated: Bool = false) -> AuroraArt {
        AuroraArt(seed: seed, primary: NL.accent2, secondary: NL.accent, animated: animated)
    }
}

/// The app mark: a rounded square of aurora with a sparkle.
struct AppGlyph: View {
    var size: CGFloat

    var body: some View {
        AuroraArt(seed: "nordic-crypto", primary: Color(hex: 0x3DDC97), secondary: Color(hex: 0x8B7CF6), scrim: false)
            .overlay {
                Image(systemName: "sparkle")
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct Wordmark: View {
    var size: CGFloat = {
        #if os(tvOS)
        44
        #else
        28
        #endif
    }()

    var body: some View {
        HStack(spacing: size * 0.3) {
            AppGlyph(size: size)
            Text(verbatim: "Nordic Crypto")
                .font(NLFont.rounded(size * 0.72))
                .foregroundStyle(NL.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
