# 00 · Status — read this first

**Project:** MUSH — an iOS Screen Time app whose brain-blob character reflects your
relationship with distracting apps.
**Target:** iPhone 16 Pro, iOS 26. Native Swift 6 / SwiftUI.
**Last updated:** 2026-09-07

---

## The one thing a new session must know

> **The app cannot run on the owner's iPhone right now.** `com.apple.developer.family-controls`
> is unavailable to a free Apple Developer Personal Team, and the owner has not enrolled
> in the $99/year program. Every Screen Time call fails without it. Details and the exact
> unblock sequence: `06-APPLE-REQUIREMENTS.md`.
>
> Development continues against `MockScreenTimeProvider`, which runs the full product in
> the iOS Simulator on a GitHub Actions `macos-26` runner. Simulator builds need no
> account and no signing.

Second thing: **there are two runtime paths.** Path A (Family Controls) is written and
correct but cannot run without the $99 membership. **Path B** measures usage with
Shortcuts automations and needs no entitlement at all — but it can only *interrupt*, never
*block*. See `09-PATH-B-NO-ENTITLEMENT.md`. The UI never calls Path B "blocking".

Fourth thing: **the widget and the Live Activity need no entitlement at all.** They are
the one part of the product that runs today on a free Apple ID, which is why the
creature reaches the Home Screen before it reaches a shield (`08-DECISIONS.md` D17).

Third thing: **Screen Time data could not leave the report extension — until iOS 26.4.**
That constraint dictated the entire two-plane architecture, and it is still true on our
deployment floor of 26.0-26.3. From 26.4, `DeviceActivityData.activityData` reads per-app
duration, pickups and notifications from ordinary app code. Read
`11-IOS-26-CHANGES.md` **before** `01-FEASIBILITY.md` section 3 - several statements in
that section are now version-dependent, and three other documented limitations moved
too (shield can open our app, shield submenus, token refresh).

---

## Two operational facts a new session needs

**The repository is public.** It was made public on 2026-09-07 because GitHub refused to
start any job: 31 runs in one day on `macos-26`, which bills at 10x the Linux rate, spent
the account's entire monthly Actions allowance in an afternoon. Public repositories get
Actions free and unlimited, so CI costs nothing now — but the habit that emptied it was
one push per edit, and that is still the lever. Batch.

**CI is the only compiler.** The owner's machine is Windows; there is no Xcode. Nothing
in this project is verified until a run goes green, and the screenshots are the only way
anyone sees the UI. Three separate guards have shipped this year that reported success
while the thing they named was broken — an ImageMagick check that printed `sigma=-1` for
every image, a gem test that counted an invisible rotation, and a blank-screen guard that
was measuring the iOS status bar. **A green check does not say the thing works. It says
whatever the check looks at is fine.** Read what a guard measures before trusting it.

---

## Environment

- Owner is on **Windows 11**. No Mac, no Xcode locally.
- Builds happen on **GitHub Actions `macos-26`** (Xcode 26, iOS 26 SDK).
- Device installs, once unblocked, happen from Windows via `ideviceinstaller`.

---

## Progress

| Phase | State |
|---|---|
| 0 · Foundation | **done** — 7 targets, XcodeGen, CI green on tests |
| 1 · Domain core + mock | **done** — 30 golden tests passing on CI |
| 2 · Authorization + selection | **blocked** — needs paid membership |
| 3 · Shield one app | **blocked** — needs paid membership |
| 4 · Monitoring + ladder | **blocked** — needs paid membership |
| 5 · Limits, schedules, focus | partial — focus sessions work against the mock |
| 6 · Statistics | **done** for our ledger; Apple plane needs a device |
| 7 · Brain system + UI | **done** — design system, creature (flat vector with per-stage motifs, 2026-09-07), 7 screens, widget, Live Activity |
| 7.5 · Competitive parity | **done** — every Opal/Brainrot feature classified in `10-FEATURE-PARITY.md`; the missing ones built |
| 8 · Interventions | **done** — Path B Shortcuts onboarding (`PathBSetupView`), the hold-to-continue pause, four synthesised soundscapes |
| 9 · Feed Quarantine | **layers 2 and 3 built** — Clean Feed in-app, and a Safari content blocker off the same rule set. Layers 1 and 4 need the membership |
| 10 · Device hardening | **blocked** — needs device |

---

## Document map

| File | Contains |
|---|---|
| `01-FEASIBILITY.md` | What iOS 26 allows, every confirmed limitation, open questions |
| `02-PRODUCT.md` | Identity, voice, loop, information architecture, MVP scope |
| `03-ARCHITECTURE.md` | Targets, two-plane data flow, threshold ladder, stores |
| `04-BRAIN-HEALTH.md` | The scoring model, fully specified and tuneable |
| `05-SHORTS-REELS.md` | Why native Reels blocking is impossible; Feed Quarantine |
| `06-APPLE-REQUIREMENTS.md` | Signing, entitlements, the exact steps only the owner can do |
| `07-ROADMAP.md` | Phases, exit criteria, ordering rationale |
| `08-DECISIONS.md` | Decision log — what was chosen and what it ruled out |
| `09-PATH-B-NO-ENTITLEMENT.md` | Running with no entitlements: what survives, what does not |
| `10-FEATURE-PARITY.md` | Every Opal and Brainrot feature, with a status. The gap analysis |
| `11-IOS-26-CHANGES.md` | What the 26.4/26.5 SDKs changed, tagged DECLARED / INFERRED / UNVERIFIED |

## Housekeeping rules for this repo

1. Update this file and `08-DECISIONS.md` whenever a phase changes state.
2. **Delete replaced approaches.** No parallel experiments left lying around.
3. Never add an API call that is not confirmed in `01-FEASIBILITY.md`. If it is new,
   research it, then add it to that table with a source.
4. No hardcoded colours, radii, fonts or durations in views — tokens only, per
   `brand/brand.json`.
