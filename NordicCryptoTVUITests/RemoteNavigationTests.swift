import XCTest

/// Apple TV is an information screen: there is nothing to navigate, and the
/// remote only switches the radio.
final class SignageRemoteTests: XCTestCase {
    private let remote = XCUIRemote.shared
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)"]
        app.launch()
    }

    func testThereIsNothingToNavigate() {
        XCTAssertTrue(app.descendants(matching: .any)["radio"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.tabBars.count, 0, "no tab bar on the information screen")
        XCTAssertEqual(app.buttons.count, 0, "no buttons on the information screen")
    }

    func testPlayPauseSwitchesTheRadio() {
        let radio = app.descendants(matching: .any)["radio"]
        XCTAssertTrue(radio.waitForExistence(timeout: 10))
        let before = radio.value as? String
        remote.press(.playPause)
        sleep(1)
        XCTAssertNotEqual(radio.value as? String, before)
        remote.press(.playPause)
        sleep(1)
        XCTAssertEqual(radio.value as? String, before, "a second press restores the radio")
    }
}
