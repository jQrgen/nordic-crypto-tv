import Foundation
#if os(iOS) || os(macOS) || os(visionOS)
import Observation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Remote notifications through the Nordic Crypto push server (push/ in this
/// repository, docs/push.md). The server keeps only the APNs token, the
/// platform, the chosen countries and the language. While push works, the
/// on-device check (`NewsAlerts`) stays quiet so nothing is announced twice;
/// when it does not (no server, no token, no network), the on-device check
/// is the fallback.
@MainActor
@Observable
final class PushRegistration {
    static let shared = PushRegistration()

    private enum Key {
        static let token = "push.token"
        static let active = "push.active"
        static let sent = "push.sent"
    }

    @ObservationIgnored private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()
    @ObservationIgnored private var pending: Task<Void, Never>?

    /// True when the server accepted this device and can deliver to it.
    private(set) var active: Bool

    private init() {
        active = UserDefaults.standard.bool(forKey: Key.active)
    }

    static var platform: String {
        #if os(macOS)
        "macos"
        #elseif os(visionOS)
        "visionos"
        #else
        UIDevice.current.userInterfaceIdiom == .pad ? "ipados" : "ios"
        #endif
    }

    /// Debug builds from Xcode get sandbox tokens; TestFlight and App Store builds get production ones.
    static var environment: String {
        #if DEBUG
        "sandbox"
        #else
        "production"
        #endif
    }

    /// Call on launch and whenever notifications are turned on: asks the system for a token
    /// (it answers through the app delegate), or unregisters when notifications are off.
    func refresh() {
        guard NewsAlerts.shared.enabled else {
            unregister()
            return
        }
        #if os(macOS)
        NSApplication.shared.registerForRemoteNotifications()
        #else
        UIApplication.shared.registerForRemoteNotifications()
        #endif
    }

    func didRegister(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        let d = UserDefaults.standard
        if let old = d.string(forKey: Key.token), old != token {
            // A new token (restore to a new device, reinstall): the server forgets the old one.
            delete(token: old)
        }
        d.set(token, forKey: Key.token)
        scheduleSync()
    }

    func didFailToRegister() {
        setActive(false)
    }

    /// Countries or language changed: send the new preferences (debounced).
    func settingsChanged() {
        guard NewsAlerts.shared.enabled else { return }
        scheduleSync(force: true)
    }

    private func scheduleSync(force: Bool = false) {
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await self?.sync(force: force)
        }
    }

    /// Registers or updates this device. Sends at most once a day when nothing changed,
    /// which also tells the server the device is still in use (unused ones are removed after 180 days).
    private func sync(force: Bool) async {
        let d = UserDefaults.standard
        guard NewsAlerts.shared.enabled, let token = d.string(forKey: Key.token) else { return }
        let countries = NewsAlerts.shared.countries.sorted()
        let language = AppLanguage.current
        let day = Calendar.current.startOfDay(for: .now).timeIntervalSince1970
        let signature = ([token, Self.platform, Self.environment, language] + countries).joined(separator: "|") + "|\(day)"
        if !force, active, d.string(forKey: Key.sent) == signature { return }

        var request = URLRequest(url: APIConfig.pushServer.appending(path: "v1/devices"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "token": token,
            "platform": Self.platform,
            "environment": Self.environment,
            "countries": countries,
            "language": language,
        ])
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let reply = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            setActive(false)
            return
        }
        let delivers = (reply["delivery"] as? Bool) == true && (reply["stored"] as? Bool) == true
        setActive(delivers)
        d.set(delivers ? signature : nil, forKey: Key.sent)
    }

    /// Notifications turned off: the server forgets this device.
    func unregister() {
        pending?.cancel()
        let d = UserDefaults.standard
        setActive(false)
        d.removeObject(forKey: Key.sent)
        guard let token = d.string(forKey: Key.token) else { return }
        delete(token: token) {
            // Forget the token only once the server has; otherwise try again next launch.
            if !NewsAlerts.shared.enabled { d.removeObject(forKey: Key.token) }
        }
    }

    private func delete(token: String, then done: (@MainActor () -> Void)? = nil) {
        var request = URLRequest(url: APIConfig.pushServer.appending(path: "v1/devices/\(token)"))
        request.httpMethod = "DELETE"
        Task {
            if let (_, response) = try? await session.data(for: request),
               (response as? HTTPURLResponse)?.statusCode == 200 {
                done?()
            }
        }
    }

    private func setActive(_ on: Bool) {
        active = on
        UserDefaults.standard.set(on, forKey: Key.active)
    }
}
#endif
