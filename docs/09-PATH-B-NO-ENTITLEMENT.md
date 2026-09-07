# 09 · Path B — running without Family Controls

Question asked: *can we avoid Family Controls and do it another way?*

Short answer: **yes for measuring and intervening, no for blocking.** This file states
exactly which half survives, because the difference is the whole product decision.

---

## 1. What was ruled out first

Before landing on Path B I checked the other candidates for blocking without the
Screen Time frameworks. All dead:

| Candidate | Verdict |
|---|---|
| `NEDNSProxyProvider` / `NEFilterDataProvider` / `NEPacketTunnelProvider` — block the apps at the network layer | Needs the **Network Extensions entitlement**, which is also unavailable to a free Personal Team. Same gate, different door. |
| Personal VPN (`NEVPNManager`) | Needs `com.apple.developer.networking.vpn.api`. Same gate. |
| A DNS-over-HTTPS configuration profile | Would work, but requires us to run a DNS server that sees every domain the user visits. Wrong privacy posture for a wellbeing app, and it blocks whole domains, not Reels. |
| Focus modes driven from Shortcuts | Focus silences notifications. It does not prevent an app from launching. |
| Anything reading the foreground app's UI | No iOS API for third parties. This is the same wall as the Reels question (`05-SHORTS-REELS.md`). |

**There is no way to prevent an app from opening on iOS without Family Controls.**
Blocking is gated, full stop.

---

## 2. What Path B actually is

Drop every entitlement-gated framework. Keep one app target and nothing else.

```
NO  FamilyControls        NO  ManagedSettings      NO  DeviceActivity
NO  app extensions        NO  App Groups           NO  network extensions
YES Shortcuts automations YES App Intents          YES WKWebView + WKContentRuleList
```

Three mechanisms, all verified, none requiring a paid membership:

### Measurement — Shortcuts automations into a background App Intent

The user creates a personal automation per watched app:

- **App → Instagram → Is Opened → Run "Mush: log open"**
- **App → Instagram → Is Closed → Run "Mush: log close"**

with *Ask Before Running* turned off, so it fires silently.

Our `AppIntent` has `openAppWhenRun = false`, which is the **default** — the intent runs
in the background without bringing Mush to the foreground. Each firing writes a timestamp
to our own container.

`close - open` gives a real session duration. Open events give real pickup counts.
**This is genuine per-app usage measurement with no entitlement at all.**

### Intervention — the same trigger, foregrounded

A second automation variant uses an intent with `openAppWhenRun = true`, which launches
Mush full-screen before the user reaches the app they were opening.

This is what one sec originally did on iOS, and it is **richer than a Screen Time
shield**: a shield is limited to an icon, two lines and two buttons, while this is our own
full SwiftUI screen — breathing, a typed delay, the character reacting, anything.

### Feed Quarantine — completely unaffected

Clean Feed (`WKWebView` + `WKContentRuleList`) needs no entitlement whatsoever. Our best
answer to Reels/Shorts survives Path B **intact**. See `05-SHORTS-REELS.md`.

---

## 3. What Path B loses, stated plainly

1. **No blocking.** The intervention appears; the user taps past it and continues. Every
   restriction becomes friction. For a lot of people friction is enough — that is one
   sec's entire thesis — but it is not the same product as a shield.
2. **Manual setup, two automations per app.** We cannot create them for the user; iOS has
   no API for that. Onboarding has to walk them through it. Ten watched apps is twenty
   automations.
3. **Trivially bypassed.** The user can disable an automation in three taps. Path A had
   the same honesty problem (L7) but at a higher friction cost.
4. **`Is Closed` reliability is unverified.** If a close event is missed, the session has
   no end. Mitigation: cap any open session at a ceiling and mark the day **partial**
   rather than inventing a duration — the same rule as a blind day in the ladder model.
5. **Background intents while the device is locked** have reported failure modes. Needs
   testing on device.
6. **Seven-day expiry.** A free Personal Team provisioning profile dies after 7 days and
   the app stops launching. Also capped at 3 apps per device and 10 App IDs.

---

## 4. Installing it from Windows, free

1. GitHub Actions (`macos-26`) builds an **unsigned** `.ipa`.
2. **Sideloadly** on Windows re-signs it with your free Apple ID and installs over USB.
   It supports iOS 26+, works with free Apple IDs, and auto-refreshes before the 7-day
   expiry so the app does not die on you.
3. Requires the non-Store versions of iTunes and iCloud for the device drivers.

No Mac, no $99, no Xcode. The cost is a weekly refresh and no true blocking.

---

## 5. How this changes the codebase

Path A is **not deleted** — it is correct, it compiles, and it is exactly what gets used
the day a membership exists. It moves behind a build configuration.

```
ScreenTimeProviding                 (the seam, unchanged)
├── LiveScreenTimeProvider          Path A. Needs $99 + device.
├── ShortcutsUsageProvider          Path B. Needs nothing.
└── MockScreenTimeProvider          Simulator and tests.
```

`BrainHealthEngine`, `UsageLedger`, streaks, achievements, statistics and the entire UI
are **unchanged**. They consume `DayRecord`, and Path B fills `DayRecord` from session
timestamps instead of from ladder rungs. That is the payoff of D7 — the provider
abstraction was written before we knew we would need this, and it absorbed a change of
data source without touching the product.

Two honest UI consequences:

- Anything labelled *blocked* becomes *interrupted* under Path B. The copy changes with
  the provider; we do not describe friction as a block.
- A day assembled from session pairs carries a `partial` flag when any open lacked a
  close, and renders like a blind day rather than being silently completed.
