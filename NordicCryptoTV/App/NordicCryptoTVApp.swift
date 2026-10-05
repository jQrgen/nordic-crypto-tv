import SwiftUI

@main
struct NordicCryptoTVApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                #if os(tvOS)
                // A news screen meant to stay on: never hand over to the screensaver.
                .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
                #endif
        }
    }
}
