# 01 · Feasibility — what iOS 26 actually allows

Researched 2026-09-07. Every claim here is sourced. Anything I could not verify is
marked **UNVERIFIED** and must be re-checked on device before we depend on it.

The rule for this file: **we never design against an API we have not confirmed exists.**

---

## 1. The four frameworks, and the one that matters most

| Framework | Role | Runs where |
|---|---|---|
| `FamilyControls` | Authorization + the opaque token types (`ApplicationToken`, `WebDomainToken`, `ActivityCategoryToken`) and `FamilyActivityPicker` | Main app |
| `ManagedSettings` | Applies the actual restriction (`ManagedSettingsStore`) | App **and** extensions |
| `ManagedSettingsUI` | Custom look of the block screen (`ShieldConfiguration`) | Shield config extension |
| `DeviceActivity` | *When* restrictions turn on/off, and usage thresholds | Monitor + report extensions |

`FamilyControls` is the gate. Everything else is inert without its authorization.

---

## 2. HARD GATE — Family Controls requires a paid Apple Developer Program membership

There are two entitlements:

- `com.apple.developer.family-controls` **(Development)** — no Apple approval needed,
  but **not available to a free Personal Team, with no exception**.
- **(Distribution)** — requires a written request per bundle ID, approved by Apple in
  days-to-weeks. Needed only for TestFlight/App Store, not for us yet.

Consequence: on a free Apple ID the app installs but `AuthorizationCenter.shared.requestAuthorization(for: .individual)`
throws, and no shield can ever be applied. There is no supported workaround.
Cost to unblock: **$99/year**.

> Sources: Apple — *Requesting the Family Controls entitlement*; hsb.horse,
> *You Cannot Run Family Controls on a Real Device with a Personal Team*.

---

## 3. THE defining constraint: Screen Time data cannot leave the report extension

> **Amended 2026-09-07 — true below iOS 26.4, false from 26.4.** The 26.4 SDK ships
> `DeviceActivityData.activityData(filteredBy:using:)`, a static function on a public
> struct that is not confined to a report scene, returning per-app duration, pickups
> and notifications. Everything in this section still governs iOS 26.0–26.3, which is
> our deployment floor, so none of it is deleted — but it is no longer the permanent
> law it was written as. Read `11-IOS-26-CHANGES.md` §1 before designing against it.

This is the single fact that shapes our whole architecture, so it gets its own section.

`DeviceActivityReport` renders inside a **deliberately restricted sandbox**. Apple DTS
(Quinn, "The Eskimo") confirmed on the developer forums, answering the direct question
*"Is DeviceActivityReportExtension intentionally sandboxed so Screen Time data cannot be
exported to the containing app?"* with a one-word reply: **Yes.**

Developers have tried and failed with: App Group `UserDefaults`, App Group shared files
via `FileManager.containerURL`, `CFPreferences`, and writing during `makeConfiguration`.
**None work.** The extension also cannot make network requests.

### What this means in practice

We can **display** Apple ground-truth screen-time numbers, but we can never **compute**
on them. A brain-health score derived from Apple totals is impossible.

### The sanctioned way to actually measure usage

`DeviceActivityMonitorExtension` is a *different* extension and **is** allowed to write
to the App Group container. Its `eventDidReachThreshold(_:activity:)` callback fires
when the user has spent a configured amount of time in a chosen set of apps.

So the only usage signal we can persist is: *"the user has now crossed N minutes in this
app set."* Register a **ladder** of events at 5, 10, 15, ... minutes and each firing
appends one rung to our own ledger. Resolution equals the ladder step. This technique is
what the entire statistics and brain-health system is built on.

---

## 4. Confirmed capabilities (safe to build on)

| Capability | API | Notes |
|---|---|---|
| Ask for Screen Time permission | `AuthorizationCenter.requestAuthorization(for: .individual)` | Device only; fails in Simulator |
| User picks apps/categories/sites | `FamilyActivityPicker` produces `FamilyActivitySelection` | Returns **opaque tokens**, not bundle IDs |
| Render a picked app name/icon | SwiftUI `Label(token)` | Only way to show what was picked |
| Block apps | `store.shield.applications = Set<ApplicationToken>` | Immediate |
| Block whole categories | `store.shield.applicationCategories` | |
| Block websites | `store.shield.webDomains` | **Host-level only** |
| Custom block screen | `ShieldConfiguration(backgroundBlurStyle:backgroundColor:icon:title:subtitle:primaryButtonLabel:primaryButtonBackgroundColor:secondaryButtonLabel:)` | Fixed layout, no custom views, no animation |
| React to block-screen buttons | `ShieldActionDelegate` returning `.none` / `.close` / `.defer` | This extension **can** write to the App Group |
| Time-based schedules | `DeviceActivityCenter.startMonitoring(_:during:events:)` | |
| Usage thresholds | `DeviceActivityEvent(applicationTokens:threshold:)` | Threshold may be under 15 min |
| Apple real stats, view-only | `DeviceActivityReport` + `DeviceActivityFilter` | Total duration, per-app, per-category, web domains, pickups, notifications |
| Path-level web filtering, our surfaces | `WKContentRuleList` in our own `WKWebView`; Safari Web Extension + Content Blocker | `block` by `url-filter`, `css-display-none` by selector |
| Trigger our app when another app opens | User-created **Shortcuts** personal automation (App, Is Opened) | Manual setup; cannot be automated on the user's behalf |

---

## 5. Confirmed limitations (design around, never pretend away)

| # | Limitation | Consequence for us |
|---|---|---|
| L1 | Report-extension data cannot reach the app (section 3) | Two-tier statistics: "Apple numbers" (display-only) vs "our ledger" (computable) |
| L2 | **Amended: iOS 26.5 added `ShieldActionResponse.openParentalControlsApp`** (`11-IOS-26-CHANGES.md` §3) — which app it opens is unverified. Below 26.5: **a shield cannot open our app.** Only `.none`/`.close`/`.defer` exist. `UIApplication.open` and `NSExtensionContext` are unavailable in `ShieldActionDelegate`. Apple: *"no supported way"* (FB15079668) | Rich interventions are reached via Shortcuts automation or a local notification, never from the shield |
| L3 | `DeviceActivitySchedule` minimum interval is **15 minutes** | A "5-minute grant" must be built from an *event threshold*, not a schedule |
| L4 | `WebDomain` shielding is **host-granular**. No paths | `youtube.com/shorts` cannot be shielded while `youtube.com` stays open |
| L5 | Tokens are opaque and **can silently change at runtime** (FB14082790) | Never persist a token as an identity key; keep stable local IDs and re-map |
| L6 | Tokens moving between `ManagedSettingsStore`s can leave a stale shield UI (FB14237883) | One named store per concern; tear down cleanly before re-applying |
| L7 | Third-party Screen Time permission has **no passcode protection** (FB18794535). The user can revoke it in Settings with one toggle | No "unbreakable" mode can be honestly promised |
| L8 | Cannot launch the *target* app from an `ApplicationToken` (FB15500695) | After a grant is issued, the user returns to the app themselves |
| L9 | Screen Time extensions run under a very tight memory budget | Shared code must be lean and dependency-free |
| L10 | **iOS 26.x regressions**: `eventDidReachThreshold` firing early, firing with 0 recorded minutes, and false positives reported on 26.2 / 26.3 | Treat every threshold firing as a *hint*, validate against our own wall-clock state, never as proof |
| L11 | `DeviceActivitySchedule` reliability degrades past roughly 45 min in field reports | Chain shorter windows and rotate activity names |
| L12 | `includesPastActivity = false` sometimes suppresses the callback entirely | Prefer `true` and de-duplicate on our side |

---

## 6. Verdict per requested feature

| Requested | Verdict | How |
|---|---|---|
| Block selected apps immediately | YES | `store.shield.applications` |
| Block selected websites | YES, host-level | `store.shield.webDomains` |
| Daily usage limits | YES | Threshold ladder, shield on the budget rung |
| Scheduled / recurring / bedtime / morning blocking | YES | `DeviceActivitySchedule` (repeats daily), one activity per window |
| Study/work modes, focus sessions, Pomodoro | YES | App-driven timer plus shields; monitor extension enforces the end |
| Configurable temporary access | YES | Shield secondary button, unshield, event-threshold re-shield (L3) |
| Intervention screen before access | PARTIAL | The **shield itself** is the reliable intervention (fixed layout). Rich custom interventions need a user-made Shortcuts automation |
| Customizable strictness | YES, with a caveat | Levels are real, but L7 means none are truly unbreakable |
| Total / per-app / per-category screen time | YES; display-only below 26.4, **computable from 26.4** | `DeviceActivityReport`, or `activityData(filteredBy:using:)` on 26.4+ (`11-IOS-26-CHANGES.md` §1) |
| Trend, streaks, interventions triggered, focus time | YES | From **our** ledger, not Apple data |
| **Selectively block Reels/Shorts inside the native app** | **NO — impossible** | See `05-SHORTS-REELS.md` |

---

## 7. Open questions to settle on a physical device

Genuinely unknown to me. Must not be assumed:

- **Q1.** Does the Screen Time web-content filter also block our own `WKWebView`? A forum
  report shows `WKWebView` returning error 105 under Screen Time content restrictions
  while `isBlockedByScreenTime` returns `false`. If shielding `instagram.com` also kills
  our Clean Feed browser, layers 1 and 2 of the Reels plan conflict and we must not
  shield the domain. **UNVERIFIED.**
- **Q2.** Practical ceiling on `DeviceActivityEvent` count per activity before the system
  degrades. Undocumented. Determines our ladder resolution.
- **Q3.** Exact severity of the iOS 26.x threshold regressions on this device's build.
- **Q4.** Whether `Label(token)` renders reliably inside extension UI or only in-app.

- **Q5.** Does `ActivityCategoryPolicy.all(except:)` really exempt the apps passed to
  it? Multiple developer-forum reports describe exempted apps still being shielded,
  with a generic shield rather than none. If true, the Allow Only mode ships broken
  and has to be withdrawn, not worked around. **UNVERIFIED.**

- **Q6.** Does `activityData` actually return data outside a report extension?
- **Q7.** `.live` versus `.cached`: latency, staleness, battery cost.
- **Q8.** Does `openParentalControlsApp` open *our* app, or Settings > Screen Time?
- **Q9.** Once the usage capability is added, can a user still grant plain `.approved`,
  or is it all-or-nothing? If all-or-nothing, adding it costs us the users who would
  have accepted shielding without surveillance.

Every one of these needs the $99 membership before it can be answered.
