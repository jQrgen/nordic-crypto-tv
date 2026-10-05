import XCTest

/// Drives the app with the Siri Remote to check that every screen's content
/// can be reached from the function keys.
final class RemoteNavigationTests: XCTestCase {
    private let remote = XCUIRemote.shared
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)"]
    }

    func testNewsletterButtonsAreReachableFromTheFunctionKeys() {
        app.launchArguments += ["-NCScreen", "brief"]
        app.launch()

        let watch = app.buttons["Watch newsreel"]
        XCTAssertTrue(watch.waitForExistence(timeout: 10))
        // Focus starts on a function key; one press down must reach the issue.
        for _ in 0..<3 where !watch.hasFocus && !app.buttons["Read issue"].hasFocus {
            remote.press(.down)
            sleep(1)
        }
        XCTAssertTrue(watch.hasFocus || app.buttons["Read issue"].hasFocus,
                      "focus never left the function keys")
    }

    func testReaderOpensAndScrolls() {
        app.launchArguments += ["-NCScreen", "brief"]
        app.launch()

        let read = app.buttons["Read issue"]
        XCTAssertTrue(read.waitForExistence(timeout: 10))
        for _ in 0..<4 where !read.hasFocus {
            remote.press(.down)
            sleep(1)
            if !read.hasFocus && app.buttons["Watch newsreel"].hasFocus { remote.press(.right); sleep(1) }
        }
        XCTAssertTrue(read.hasFocus)
        remote.press(.select)
        sleep(2)

        let welcome = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Hi, and welcome'")).firstMatch
        XCTAssertTrue(welcome.waitForExistence(timeout: 5), "reader did not open")
        let startY = welcome.frame.minY
        for _ in 0..<6 { remote.press(.down) }
        sleep(1)
        XCTAssertLessThan(welcome.frame.minY, startY, "reader did not scroll")
    }
}
