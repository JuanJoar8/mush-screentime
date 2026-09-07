# 08 · Decision log

Append-only. Each entry: what was decided, what it rules out, and why.

---

### D1 · Native Swift/SwiftUI, not cross-platform
**Decided 2026-09-07.** The entire product value is `FamilyControls` / `ManagedSettings`
/ `DeviceActivity`, which exist only in native code and are consumed largely *inside app
extensions*. React Native or Flutter would require a bridge for every core call and could
not host the shield or monitor extensions at all. Cross-platform buys nothing here.
**Rules out:** any future Android port sharing this codebase. Accepted — Android would
need a different blocking architecture anyway (`AccessibilityService`).

### D2 · Two independent data planes
**Decided 2026-09-07.** Apple DTS confirmed the report extension is intentionally
sandboxed and its data cannot reach the app. So brain health is computed **only** from
our own ledger, and Apple's numbers are display-only with a provenance chip.
**Rules out:** any metric that mixes the two. **Ruled out explicitly:** the community
hacks that attempt to smuggle report data through App Group storage — they do not work,
and if they ever did they would be defeating a deliberate privacy boundary.

### D3 · Threshold ladder as the usage sensor
**Decided 2026-09-07.** `eventDidReachThreshold` in the monitor extension is the only
persistable usage signal. Default 5-minute rungs, ladder to 2x budget, 48-event cap.
**Trade-off:** resolution is quantised to the rung. Finer rungs mean more events, more
battery, and more exposure to the iOS 26.x threshold bugs. 5 minutes is a guess with a
safety margin, revisited in Phase 10 on real hardware.

### D4 · One `ManagedSettingsStore` per concern
**Decided 2026-09-07.** Named stores (`manual`, `schedule.<id>`, `limit`, `focus`,
`quarantine`). Mitigates FB14237883, where tokens migrating between stores leave a stale
shield UI. **Rules out:** the simpler single-store design.

### D5 · Grants are usage-time, not wall-clock
**Decided 2026-09-07.** `DeviceActivitySchedule` has a 15-minute floor, so a "5 more
minutes" grant is implemented as a 5-minute `DeviceActivityEvent` threshold inside a
1-hour window. Forced by the API — and it is the better product behaviour anyway: five
minutes of *use*, not five minutes during which you put the phone down.

### D6 · No CoreData / SwiftData
**Decided 2026-09-07.** Screen Time extensions have a very tight memory budget and may be
woken for milliseconds. Data volume is ~1 record/day. App Group `UserDefaults` for hot
state, atomic JSON files for history.
**Revisit if:** the ledger grows beyond a few thousand records, which at one per day is
years away.

### D7 · Provider abstraction with a mock, from day one
**Decided 2026-09-07.** `ScreenTimeProviding` with `Live` and `Mock` implementations.
Not speculative architecture — Family Controls does not work in the Simulator *at all*,
so without it no UI could ever be previewed, and right now the mock is the only way to
run the product end to end. **Rules out:** calling framework types directly from views.

### D8 · Missing data scores zero and is marked
**Decided 2026-09-07.** A day with no ledger signal gets `Δ = 0`, is not green, does not
extend or break a streak, and renders hollow. Given the iOS 26.x regressions that fire
thresholds at zero minutes, silently trusting an empty day would produce actively wrong
scores. **Rules out:** treating absence of evidence as evidence of a good day.

### D9 · Native Reels/Shorts blocking declared impossible; Feed Quarantine instead
**Decided 2026-09-07.** Verified against one sec's own documentation and the absence of
any iOS equivalent to Android's `AccessibilityService`. We ship four honest layers
instead (`05-SHORTS-REELS.md`) and label each one by what it actually does.
**Rules out:** VPN/TLS-interception approaches (privacy posture, and Instagram pins
certificates), and any marketing claim of in-app Reels blocking.

### D10 · GitHub Actions over a rented Mac
**Decided 2026-09-07.** `macos-26` runners are GA with Xcode 26 and the iOS 26 SDK, cost
effectively nothing at our volume, and Simulator builds need no signing or Apple account.
**Trade-off, stated plainly:** no interactive debugger, no Instruments. If Phase 4
extension debugging stalls, renting a Mac for a few days is the right escalation rather
than pushing through blind.

### D11 · Home puts the primary action above the fold, and fuses health with the character
**Decided 2026-09-07.** Departs from the hierarchy suggested in the brief. The health
number renders on the character rather than as a separate row (the two said the same
thing twice), and the contextual primary action moves directly beneath it, because the
moment of intent in a self-control app is fragile and should not require scrolling.

### D12 · XcodeGen, project file not committed
**Decided 2026-09-07.** `project.yml` is the source of truth; `Mush.xcodeproj` is
generated in CI and git-ignored. A hand-maintained `.pbxproj` across 7 targets edited by
an agent that cannot compile it is a guaranteed source of silent corruption.
**Rules out:** Tuist (heavier, needs its own toolchain install) and checked-in project
files.
