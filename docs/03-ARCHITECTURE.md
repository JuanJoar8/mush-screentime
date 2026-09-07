# 03 · Architecture

Native iOS. Swift 6, SwiftUI, iPhone-only, minimum deployment **iOS 26.0** (we target a
single known device, so there is no reason to carry back-compat).

No cross-platform framework. The entire product value is Apple-specific Screen Time
integration that only exists in native code; React Native or Flutter would add a bridge
for every single core call and buy nothing.

---

## 1. Targets

| Target | Kind | Extension point | Why |
|---|---|---|---|
| `Mush` | iOS app | — | The product |
| `MushKit` | local Swift package | — | Domain logic shared by app **and** extensions |
| `MushMonitor` | app extension | `com.apple.deviceactivity.monitor-extension` | Applies/removes shields on schedule; **the only place usage can be recorded** |
| `MushShieldUI` | app extension | `com.apple.ManagedSettingsUI.shield-configuration-service` | The look of the block screen |
| `MushShieldAction` | app extension | `com.apple.ManagedSettings.shield-action-service` | Block-screen button handling, grants, counters |
| `MushReport` | app extension | `com.apple.deviceactivity.report-extension` | Renders Apple ground-truth stats (sandboxed, output-only) |
| `MushWebGuard` | Safari web extension | — | Phase 9: Reels/Shorts rules in Safari |
| `MushKitTests` | unit tests | — | Brain engine, scheduling, ledger |

App Group: `group.<TEAM_PREFIX>.mush` — the **only** channel between app and extensions.

> `MushKit` must stay lean and dependency-free. Screen Time extensions run under a very
> tight memory budget (L9); a fat shared module is the classic way to get them killed.

---

## 2. The data-flow, which is dictated by one constraint

Because report-extension data can never reach the app (L1), there are **two independent
data planes** and they never merge:

```
                  PLANE A — ours, computable
  ┌────────────────────────────────────────────────────────┐
  │  MushMonitor extension                                 │
  │    intervalDidStart      -> apply shields              │
  │    intervalDidEnd        -> remove shields             │
  │    eventDidReachThreshold-> append rung to UsageLedger  │
  │  MushShieldAction extension                            │
  │    shield shown / override / grant -> append to ledger  │
  └───────────────────────┬────────────────────────────────┘
                          │ App Group container
                          ▼
  ┌────────────────────────────────────────────────────────┐
  │  Mush app:  UsageLedger -> BrainHealthEngine -> UI      │
  └────────────────────────────────────────────────────────┘

                  PLANE B — Apple's, display-only
  ┌────────────────────────────────────────────────────────┐
  │  MushReport extension renders SwiftUI directly onscreen │
  │  Numbers are visible to the user, invisible to our code │
  └────────────────────────────────────────────────────────┘
```

Plane B is embedded in the app as a `DeviceActivityReport` view. The UI marks those
cards with a small "Apple" provenance chip, because they are the only numbers we cannot
explain the derivation of.

---

## 3. Measuring usage: the threshold ladder

The one legitimate way to persist usage (see feasibility section 3).

For a monitored app-set, register a `DeviceActivityEvent` per rung:

```
rung k  ->  DeviceActivityEvent(applicationTokens: set,
                                threshold: .init(minute: k * step))
```

- `step` default **5 minutes**, configurable
- ladder height = `2 x dailyBudget`, so we can still measure overshoot
- default ceiling **48 events** per activity (Q2 is undocumented — this is a guess with a
  safety margin, and it is flagged as such)
- **per-app ladders** for up to 5 user-chosen "watched" apps, plus one aggregate ladder
  for everything else. Per-app ladders multiply event count, which is why they are capped.

### Defending against the iOS 26.x regressions (L10)

Thresholds are firing early and firing at zero minutes on 26.2/26.3. So the monitor
extension treats every firing as a **hint**, not a fact:

1. record wall-clock time of each firing
2. reject a rung whose firing is physically impossible given the previous rung
   (e.g. rung k+3 arriving 40 s after rung k+2 when `step` is 5 min)
3. persist both the accepted value and the raw firing, so the discrepancy is auditable
4. never shield on a single unvalidated firing when strictness is below `strict`

---

## 4. Blocking engine

One `ManagedSettingsStore` **per concern**, named — never a single shared store. This is
the mitigation for L6 (stale shield UI when tokens migrate between stores):

| Store name | Owns |
|---|---|
| `manual` | user-initiated "block now" |
| `schedule.<id>` | one per recurring window (bedtime, morning, work) |
| `limit` | shields applied because a daily budget was reached |
| `focus` | active focus / Pomodoro session |
| `quarantine` | Feed Quarantine layer 1 |

`BlockingEngine` in `MushKit` is the only thing allowed to mutate a store, and it is
compiled into both the app and the monitor extension.

### Temporary access ("5 more minutes")

L3 says a `DeviceActivitySchedule` cannot be shorter than 15 minutes, so a 5-minute grant
is built from an **event threshold** instead:

1. `ShieldActionExtension` removes the token from the store and writes a `Grant` record
2. it starts a monitoring window of 1 hour containing a single event with a
   `threshold` of 5 minutes of usage on that token
3. `eventDidReachThreshold` re-applies the shield

The grant is usage-time-based rather than wall-clock, which is actually the better
product behaviour: five minutes of *use*, not five minutes of the clock.

---

## 5. Interventions

| Surface | Reach | Fidelity |
|---|---|---|
| **Shield** (`ShieldConfiguration`) | always, reliable | low — icon, title, subtitle, 2 buttons, colours. No custom views, no animation |
| **Our app via Shortcuts automation** | only if the user builds the automation | full — breathing, typing, reflection, character animation |
| **Local notification** | unreliable under Focus | low |

A shield **cannot** open our app (L2, Apple-confirmed). So the architecture is: the
shield is the guaranteed baseline intervention, and the Shortcuts automation is an opt-in
upgrade we guide the user through in onboarding. This is precisely how one sec works on
iOS, and there is no better path available.

---

## 6. Persistence

- **App Group `UserDefaults`** — small, hot, extension-written state: active grants,
  today's rungs, shield counters. Must stay tiny; extensions write here under memory
  pressure.
- **App Group file store (JSON, atomic writes)** — the `UsageLedger` day records and
  `HealthEntry` history. Append-mostly, read by the app.
- **No CoreData / SwiftData.** Extension memory budget (L9) plus the fact that the
  monitor extension may be woken for a few hundred milliseconds makes a heavy stack a
  liability. The data volume is roughly one record per day.
- `FamilyActivitySelection` is `Codable` and stored in the App Group. Tokens inside it
  are opaque and may rotate (L5), so we key everything on **our own stable UUIDs** and
  treat the token as a mutable attribute of our record.

---

## 7. The provider abstraction (and why it exists right now)

```swift
protocol ScreenTimeProviding {
    func requestAuthorization() async throws
    var authorizationStatus: AuthorizationStatus { get }
    func applyShield(_ tokens: ShieldTargets, store: StoreName)
    func startMonitoring(_ plan: MonitoringPlan) throws
    func todayLedger() -> DayRecord
}
```

Two implementations:

- `LiveScreenTimeProvider` — the real frameworks. Device only, needs the paid membership.
- `MockScreenTimeProvider` — synthetic but *plausible* usage curves, scripted shield
  events, a fast-forward clock.

This is not scaffolding for its own sake. It is load-bearing for three reasons:

1. **Family Controls does not work in the Simulator at all**, even with a paid account.
   Without a mock, no UI work could ever be previewed.
2. The current account situation (no paid membership) means the mock is the *only* way
   to run the product end to end.
3. `BrainHealthEngine` must be unit-testable against fixed scenarios, which requires
   injected data.

Selected by a launch argument / build config, never by a runtime user setting.
