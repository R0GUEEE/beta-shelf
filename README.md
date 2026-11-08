# Beta Shelf

A native SwiftUI browser for public TestFlight betas, built to feel like the App Store.

![icon](docs/icon.png)

## What it does

- **Discover** — a curated catalogue of public TestFlight invites, presented with App Store metadata
  (icon, seller, category, rating, screenshots, description). Featured hero carousel, genre shelves,
  category chips, live filter.
- **Live availability** — every link is checked against Apple's own public invite page
  (`testflight.apple.com/join/<code>`), which server-renders the beta's title, icon and status.
  Statuses are cached for six hours and refreshed on pull-to-refresh.
- **Search** — searches the on-device catalogue and the iTunes Search API side by side, so you can
  look up any App Store app and see whether a public beta is indexed for it.
- **My Betas** — paste any invite link (or just the 8-character code); Beta Shelf resolves it,
  enriches it with App Store metadata when available, and tracks its status locally.
- **Join** — the Join button opens `itms-beta://testflight.apple.com/join/<code>`, which hands off
  to the TestFlight app.

No account, no API key, no backend, no analytics. The catalogue ships inside the app bundle.

## Architecture

```
Sources/BetaShelf/
├── App/            BetaShelfApp, RootView (TabView)
├── Models/         BetaApp, StoreApp, BetaStatus
├── Services/       CatalogStore, TestFlightResolver, AppStoreClient
└── Views/          BrowseView, BetaDetailView, SearchView, MyBetasView, SettingsView, Components
Resources/catalog.json   138 public betas with App Store metadata
tools/                    catalogue harvest / resolve / merge pipeline (Python 3, stdlib only)
```

- iOS 16 minimum, SwiftUI, no third-party dependencies.
- `CatalogStore` is a `@MainActor` observable object: bundled catalogue + user links + status cache
  persisted to Application Support.
- `TestFlightResolver` parses the public invite page with `NSRegularExpression` and classifies the
  link as `open` / `full` / `closed`.

## Building

The project is described in `project.yml` and generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
cd BetaShelf
xcodegen generate
xcodebuild -project BetaShelf.xcodeproj -scheme BetaShelf -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
```

GitHub Actions builds an **unsigned** IPA on `macos-15` for every push to `main`
(`.github/workflows/build.yml`); tagging `v*` attaches the IPA to a release. Sign it with
Sideloadly / SideStore / AltStore / TrollStore before installing.

## Refreshing the catalogue

```sh
cd tools
python3 harvest.py       # collect join codes (Telegram public web previews)
python3 resolve.py       # read each invite page -> name, icon, availability
python3 enrich.py        # iTunes Search API -> App Store metadata
python3 merge.py         # -> catalog.json
cp catalog.json ../Resources/catalog.json
```

`resolve.py` and `enrich.py` are rate-limited on purpose: iTunes throttles around 20 requests/minute,
so enrichment sleeps ~2 s per app and is resumable.

## Disclaimer

Beta Shelf is not affiliated with Apple Inc. TestFlight is a trademark of Apple Inc. Every link in
the bundled catalogue is a public invite published by its developer; developers can withdraw a link
at any time, which the app surfaces as `CLOSED`.
