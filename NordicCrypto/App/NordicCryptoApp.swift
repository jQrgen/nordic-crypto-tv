import SwiftUI

@main
struct NordicCryptoApp: App {
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

        #if os(visionOS)
        WindowGroup(id: "newsreel", for: URL.self) { $url in
            if let url { NewsreelWindow(url: url) }
        }
        .defaultSize(width: 1280, height: 720)
        #endif
    }
}
