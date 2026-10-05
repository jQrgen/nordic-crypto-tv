# Nordic Crypto for Apple TV

A terminal-style (Bloomberg-like) news app for tvOS 18+, built on the
[Nordic Crypto data API v1](https://github.com/jQrgen/nordic-crypto) (`/api/v1/`).

- **F1 Top news**: lead story, the latest list, topic board, upcoming events, more headlines
- **F2 Nordics**: one column per country (NO SE DK FI IS) with local clocks
- **F3 Events**: event table, then detail with a QR code for tickets
- **F4 Newsletter**: latest issue, newsreel video in the system player, full-text reader
- Headline ticker, Nordic world clocks, LIVE/OFFLINE status, "not investment advice"
- Stories open full screen with the Nordic Crypto summary and a QR code to the source (Apple TV has no browser)
- UI in en, nb, nn, sv, da, fi, is; story summaries use the API's `summary_i18n` for the device language
- No accounts, no tracking, no data collected (`PrivacyInfo.xcprivacy`)

## Data
`Model/APIClient.swift` tries `https://cryptonordic.no/api/v1/` and then
`https://jqrgen.github.io/nordic-crypto/api/v1/`. The last good response is kept in Caches. A snapshot
of the API (`NordicCryptoTV/Resources/Snapshot/`) ships in the app, so the first launch and offline use always
show content. To refresh the snapshot, run `python3 tools/api_feed.py` in the nordic-crypto repo
and copy `news.json`, `events.json`, `newsletters.json` and `newsletters/*.json` from `site/api/v1/`.

## Build
```sh
brew install xcodegen
xcodegen generate
open NordicCryptoTV.xcodeproj
```
Tests: `xcodebuild test -scheme NordicCryptoTV -destination 'platform=tvOS Simulator,name=<sim>'`.
Assets: `python3 support/make_brand_assets.py` redraws the layered icons and Top Shelf images.
Screenshots: `support/screenshots.sh <sim-id> <path/to/Nordic Crypto.app> <out-dir>` (Debug build; uses `-NCScreen`/`-NCOpen`).

## Before App Store submission
1. The API must be live over HTTPS: merge and publish nordic-crypto PR #5 (`/api/v1`), and enable
   "Enforce HTTPS" for the custom domain in the GitHub Pages settings (the certificate for `cryptonordic.no`
   is not issued yet, and `jqrgen.github.io` redirects to plain `http://cryptonordic.no`, which tvOS blocks).
2. Set `DEVELOPMENT_TEAM` in `project.yml` to the team that will publish the app, and register the bundle id
   `no.cryptonordic.tv` (or change it).
3. Create the app in App Store Connect: privacy policy URL, privacy label "Data Not Collected", category News,
   age rating, description and keywords in the 7 languages, 1920x1080 screenshots.
4. Product > Archive in Xcode, then Distribute App > App Store Connect, TestFlight on a real Apple TV, then submit.
