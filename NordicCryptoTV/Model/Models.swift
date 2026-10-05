import Foundation

// Types for the Nordic Crypto data API, version 1 (/api/v1/).
// The API promises that v1 field names stay but new fields may appear, so
// everything except ids and titles is optional and unknown keys are ignored.

struct NewsFeed: Decodable {
    var generatedAt: Date?
    var updated: Date?
    var items: [NewsItem]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at", updated, items
    }
}

struct NewsItem: Decodable, Identifiable, Hashable {
    var id: String
    var url: URL?
    var title: String
    var titleEn: String?
    var sourceName: String?
    var country: String?
    var language: String?
    var languageCode: String?
    var published: Date?
    var topics: [String]
    var summary: String?
    var summaryI18n: [String: String]
    var paywall: Bool
    var ownStory: Bool

    enum CodingKeys: String, CodingKey {
        case id, url, title, country, language, published, topics, summary, paywall
        case titleEn = "title_en", sourceName = "source_name", languageCode = "language_code"
        case summaryI18n = "summary_i18n", ownStory = "own_story"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        url = try? c.decodeIfPresent(URL.self, forKey: .url)
        titleEn = try c.decodeIfPresent(String.self, forKey: .titleEn)
        sourceName = try c.decodeIfPresent(String.self, forKey: .sourceName)
        country = try c.decodeIfPresent(String.self, forKey: .country)
        language = try c.decodeIfPresent(String.self, forKey: .language)
        languageCode = try c.decodeIfPresent(String.self, forKey: .languageCode)
        published = try? c.decodeIfPresent(Date.self, forKey: .published)
        topics = (try? c.decodeIfPresent([String].self, forKey: .topics)) ?? []
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
        summaryI18n = (try? c.decodeIfPresent([String: String].self, forKey: .summaryI18n)) ?? [:]
        paywall = (try? c.decodeIfPresent(Bool.self, forKey: .paywall)) ?? false
        ownStory = (try? c.decodeIfPresent(Bool.self, forKey: .ownStory)) ?? false
    }

    /// Headline in the reader's language when we have one, else the original.
    func headline(for lang: String) -> String {
        if languageCode.map({ AppLanguage.sameFamily($0, lang) }) == true { return title }
        return titleEn ?? title
    }

    /// The original-language headline, when it differs from `headline(for:)`.
    func originalHeadline(for lang: String) -> String? {
        let shown = headline(for: lang)
        return shown == title ? nil : title
    }

    func summary(for lang: String) -> String? {
        summaryI18n[lang] ?? summary
    }
}

struct EventsFeed: Decodable {
    var events: [EventItem]
}

struct EventItem: Decodable, Identifiable, Hashable {
    var id: String
    var title: String
    var titleOriginal: String?
    var start: Date?
    var end: Date?
    var place: String?
    var city: String?
    var country: String?
    var online: Bool
    var organiser: String?
    var url: URL?
    var paid: Bool?
    var sponsored: String?
    var note: String?
    var noteI18n: [String: String]
    var past: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, start, end, place, city, country, online, organiser, url, paid, sponsored, note, past
        case titleOriginal = "title_original", noteI18n = "note_i18n"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        titleOriginal = try c.decodeIfPresent(String.self, forKey: .titleOriginal)
        start = try? c.decodeIfPresent(Date.self, forKey: .start)
        end = try? c.decodeIfPresent(Date.self, forKey: .end)
        place = try c.decodeIfPresent(String.self, forKey: .place)
        city = try c.decodeIfPresent(String.self, forKey: .city)
        country = try c.decodeIfPresent(String.self, forKey: .country)
        online = (try? c.decodeIfPresent(Bool.self, forKey: .online)) ?? false
        organiser = try c.decodeIfPresent(String.self, forKey: .organiser)
        url = try? c.decodeIfPresent(URL.self, forKey: .url)
        paid = try? c.decodeIfPresent(Bool.self, forKey: .paid)
        // `sponsored` is a sponsor name or null; tolerate a bool as well.
        if let name = try? c.decodeIfPresent(String.self, forKey: .sponsored) {
            sponsored = name
        } else if (try? c.decodeIfPresent(Bool.self, forKey: .sponsored)) == true {
            sponsored = ""
        }
        note = try c.decodeIfPresent(String.self, forKey: .note)
        noteI18n = (try? c.decodeIfPresent([String: String].self, forKey: .noteI18n)) ?? [:]
        past = (try? c.decodeIfPresent(Bool.self, forKey: .past)) ?? false
    }

    func note(for lang: String) -> String? {
        noteI18n[lang] ?? note
    }
}

struct NewslettersFeed: Decodable {
    var issues: [NewsletterIssue]
}

struct NewsletterEnvelope: Decodable {
    var item: NewsletterIssue
}

struct NewsletterIssue: Decodable, Identifiable, Hashable {
    var id: String
    var number: Int?
    var date: String?
    var title: String
    var subtitle: String?
    var titleI18n: [String: String]
    var subtitleI18n: [String: String]
    var stories: Int?
    var events: Int?
    var signOff: String?
    var htmlURL: URL?
    var apiURL: URL?
    /// Only present on the single-issue endpoint (`newsletters/{id}.json`).
    var text: String?
    var textI18n: [String: String]
    var video: Newsreel?

    enum CodingKeys: String, CodingKey {
        case id, number, date, title, subtitle, stories, events, text, video
        case titleI18n = "title_i18n", subtitleI18n = "subtitle_i18n", signOff = "sign_off"
        case htmlURL = "html_url", apiURL = "api_url", textI18n = "text_i18n"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        number = try? c.decodeIfPresent(Int.self, forKey: .number)
        date = try? c.decodeIfPresent(String.self, forKey: .date)
        subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle)
        titleI18n = (try? c.decodeIfPresent([String: String].self, forKey: .titleI18n)) ?? [:]
        subtitleI18n = (try? c.decodeIfPresent([String: String].self, forKey: .subtitleI18n)) ?? [:]
        // `stories`/`events` are counts in the list and may be arrays in the detail.
        stories = try? c.decodeIfPresent(Int.self, forKey: .stories)
        events = try? c.decodeIfPresent(Int.self, forKey: .events)
        signOff = try c.decodeIfPresent(String.self, forKey: .signOff)
        htmlURL = try? c.decodeIfPresent(URL.self, forKey: .htmlURL)
        apiURL = try? c.decodeIfPresent(URL.self, forKey: .apiURL)
        text = try c.decodeIfPresent(String.self, forKey: .text)
        textI18n = (try? c.decodeIfPresent([String: String].self, forKey: .textI18n)) ?? [:]
        video = try? c.decodeIfPresent(Newsreel.self, forKey: .video)
    }

    func title(for lang: String) -> String { titleI18n[lang] ?? title }
    func subtitle(for lang: String) -> String? { subtitleI18n[lang] ?? subtitle }
    func text(for lang: String) -> String? { textI18n[lang] ?? text }
}

struct Newsreel: Decodable, Hashable {
    var durationSeconds: Int?
    var downloadURL: URL?
    var fileURL: URL?
    var posterURL: URL?

    enum CodingKeys: String, CodingKey {
        case durationSeconds = "duration_seconds", downloadURL = "download_url"
        case fileURL = "file_url", posterURL = "poster_url"
    }

    /// The GitHub release asset is served over HTTPS today, so try it first.
    var playableURL: URL? { downloadURL ?? fileURL }
}

enum Country: String, CaseIterable, Identifiable {
    case no = "NO", se = "SE", dk = "DK", fi = "FI", `is` = "IS"
    var id: String { rawValue }

    var name: String {
        switch self {
        case .no: String(localized: "Norway")
        case .se: String(localized: "Sweden")
        case .dk: String(localized: "Denmark")
        case .fi: String(localized: "Finland")
        case .is: String(localized: "Iceland")
        }
    }

    var capital: String {
        switch self {
        case .no: "OSLO"
        case .se: "STOCKHOLM"
        case .dk: "COPENHAGEN"
        case .fi: "HELSINKI"
        case .is: "REYKJAVIK"
        }
    }

    var timeZone: TimeZone {
        switch self {
        case .no: TimeZone(identifier: "Europe/Oslo")!
        case .se: TimeZone(identifier: "Europe/Stockholm")!
        case .dk: TimeZone(identifier: "Europe/Copenhagen")!
        case .fi: TimeZone(identifier: "Europe/Helsinki")!
        case .is: TimeZone(identifier: "Atlantic/Reykjavik")!
        }
    }
}

enum AppLanguage {
    /// Languages the API translates our own text into.
    static let supported = ["nb", "nn", "sv", "da", "fi", "is"]

    /// The best API language for this device: nb, nn, sv, da, fi, is or en.
    static var current: String { resolve(Locale.preferredLanguages) }

    static func resolve(_ preferred: [String]) -> String {
        for tag in preferred {
            let code = Locale(identifier: tag).language.languageCode?.identifier ?? tag
            if code == "no" { return "nb" }
            if supported.contains(code) || code == "en" { return code }
        }
        return "en"
    }

    /// Norwegian sources are tagged "no"; treat nb and nn as the same family.
    static func sameFamily(_ a: String, _ b: String) -> Bool {
        let norsk: Set<String> = ["no", "nb", "nn"]
        return a == b || (norsk.contains(a) && norsk.contains(b))
    }
}
