import Foundation

enum APIConfig {
    /// Tried in order. The custom domain is the canonical home; GitHub Pages
    /// redirects there once HTTPS is enforced on the Pages site.
    static let bases: [URL] = [
        URL(string: "https://cryptonordic.no/api/v1/")!,
        URL(string: "https://jqrgen.github.io/nordic-crypto/api/v1/")!,
    ]
    static let site = URL(string: "https://cryptonordic.no/")!
    static let refreshInterval: Duration = .seconds(10 * 60)
}

enum APIError: Error {
    case unavailable(String)
}

/// Fetches API documents, keeps the last good copy in Caches, and falls back
/// to the snapshot bundled with the app so the screen is never empty.
struct APIClient {
    var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.requestCachePolicy = .reloadRevalidatingCacheData
        return URLSession(configuration: config)
    }()
    var bundle: Bundle = .main

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        let plain = ISO8601DateFormatter()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dayOnly = ISO8601DateFormatter()
        dayOnly.formatOptions = [.withFullDate]
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            if let date = plain.date(from: s) ?? fractional.date(from: s) ?? dayOnly.date(from: s) {
                return date
            }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date \(s)"))
        }
        return d
    }()

    /// Live document from the network, trying each base in turn.
    func fetch<T: Decodable>(_ type: T.Type, path: String) async throws -> T {
        var lastError: Error = APIError.unavailable(path)
        for base in APIConfig.bases {
            do {
                let url = base.appending(path: path)
                let (data, response) = try await session.data(from: url)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    throw APIError.unavailable("\(url) HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                }
                let value = try Self.decoder.decode(T.self, from: data)
                try? data.write(to: cacheURL(path), options: .atomic)
                return value
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    /// Last good network copy, or the bundled snapshot.
    func offline<T: Decodable>(_ type: T.Type, path: String) -> T? {
        if let data = try? Data(contentsOf: cacheURL(path)),
           let value = try? Self.decoder.decode(T.self, from: data) {
            return value
        }
        guard let url = bundle.url(forResource: "Snapshot/" + path, withExtension: nil),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? Self.decoder.decode(T.self, from: data)
    }

    private func cacheURL(_ path: String) -> URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appending(path: "api-v1-" + path.replacingOccurrences(of: "/", with: "-"))
    }
}
