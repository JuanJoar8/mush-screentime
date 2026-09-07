# MUSH

*Don't let it turn to mush.*

An iPhone Screen Time app built around a brain-blob whose condition tracks your
relationship with distracting apps. Native Swift 6 / SwiftUI, iOS 26, iPhone-only.

**Start with [`docs/00-STATUS.md`](docs/00-STATUS.md).** It carries the two facts that
shape everything else.

## The short version

1. **The app cannot run on a real iPhone without a paid Apple Developer membership.**
   `com.apple.developer.family-controls` is unavailable to a free Personal Team. Not a
   workaround-able limitation. See [`docs/06-APPLE-REQUIREMENTS.md`](docs/06-APPLE-REQUIREMENTS.md).
2. **Apple's Screen Time data can never reach our app code.** The report extension is
   deliberately sandboxed, confirmed by Apple DTS. Brain health is therefore computed
   from our own ledger, built from `DeviceActivityEvent` threshold firings. See
   [`docs/01-FEASIBILITY.md`](docs/01-FEASIBILITY.md) section 3.
3. **Selectively blocking Reels inside the native Instagram app is impossible on iOS.**
   Android does it with `AccessibilityService`; iOS has no equivalent. We ship Feed
   Quarantine instead, and label each layer by what it actually does. See
   [`docs/05-SHORTS-REELS.md`](docs/05-SHORTS-REELS.md).

## Layout

```
App/                 the iOS app target
Extensions/          monitor, shield UI, shield action, report
Packages/MushKit/    MushKit (pure logic) + MushScreenTime (Apple framework glue)
Config/              bundle IDs and team, in one place
docs/                architecture, feasibility, product, roadmap, decisions
brand/               design tokens (Phase 7)
```

## Building

There is no `.xcodeproj` in the repo — `project.yml` is the source of truth.

```sh
brew install xcodegen
xcodegen generate
open Mush.xcodeproj
```

Domain tests need no Xcode at all:

```sh
cd Packages/MushKit && swift test
```

CI builds the app and all five extensions for the Simulator on a `macos-26` runner and
uploads screenshots. Simulator builds are unsigned, so that path needs no Apple account.
