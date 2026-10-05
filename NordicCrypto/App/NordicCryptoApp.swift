import SwiftUI
#if os(iOS)
import BackgroundTasks
import UserNotifications
#elseif os(macOS)
import UserNotifications
#endif

@main
struct NordicCryptoApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor private var delegate: AppDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    #endif
    #if os(iOS) || os(macOS)
    @Environment(\.scenePhase) private var scenePhase
    #endif

    var body: some Scene {
        WindowGroup {
            RootView()
                #if os(tvOS)
                .preferredColorScheme(.dark)
                // A news screen meant to stay on: never hand over to the screensaver.
                .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
                #elseif os(macOS)
                .frame(minWidth: 900, minHeight: 620)
                #endif
        }
        #if os(visionOS)
        .defaultSize(width: 1280, height: 820)
        #elseif os(macOS)
        .defaultSize(width: 1440, height: 872)
        #endif
        #if os(iOS) || os(macOS)
        .onChange(of: scenePhase) { _, phase in
            NewsAlerts.shared.foreground = phase == .active
            #if os(iOS)
            if phase == .background { AppDelegate.scheduleRefresh() }
            #endif
        }
        #endif
        #if os(iOS)
        .backgroundTask(.appRefresh(AppDelegate.refreshTask)) {
            await AppDelegate.scheduleRefreshAsync()
            await NewsAlerts.check()
        }
        #endif

        #if os(visionOS)
        WindowGroup(id: "newsreel", for: URL.self) { $url in
            if let url { NewsreelWindow(url: url) }
        }
        .defaultSize(width: 1280, height: 720)
        #endif

        #if os(macOS)
        Settings {
            AlertSettingsView()
                .frame(width: 460, height: 420)
        }
        MenuBarExtra("Nordic Crypto", systemImage: "sparkle") {
            MenuBarHeadlines()
        }
        #endif
    }
}

#if os(iOS)
final class AppDelegate: NSObject, UIApplicationDelegate {
    static let refreshTask = "no.cryptonordic.tv.refresh"

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared
        Self.scheduleRefresh()
        return true
    }

    /// Asks iOS to wake the app for a news check in about 15 minutes.
    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTask)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func scheduleRefreshAsync() async { scheduleRefresh() }
}
#elseif os(macOS)
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var poller: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared
        // Keeps checking while the app runs, also with every window closed.
        poller = Task.detached {
            while !Task.isCancelled {
                await NewsAlerts.check()
                try? await Task.sleep(for: .seconds(15 * 60))
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

/// The menu bar menu: the latest headlines and a way back to the window.
private struct MenuBarHeadlines: View {
    @State private var store = FeedStore()
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ForEach(store.news.prefix(8)) { item in
            Button {
                if let url = item.url { NSWorkspace.shared.open(url) }
            } label: {
                Text(verbatim: "\(item.country ?? "") · \(item.headline(for: store.lang))")
            }
        }
        Divider()
        SettingsLink { Text("Notifications…") }
        Button("Quit Nordic Crypto") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
#endif
