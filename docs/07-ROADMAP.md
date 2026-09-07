# 07 · Implementation phases

Vertical slices. Each phase ends in something that **runs**, not in a layer that waits
for another layer. An ugly working prototype beats thirty beautiful screens on fake data.

Phases marked **[DEVICE]** cannot be completed without the $99 membership and a
registered iPhone. Everything else is reachable from Windows today.

---

### Phase 0 — Foundation
Repo, docs, `XcodeGen` spec, 7 targets, App Group, entitlements, CI that compiles.
*Exit: `xcodebuild` succeeds on the macOS 26 runner for app + all extensions.*

### Phase 1 — Domain core, no UI
`MushKit`: models, `UsageLedger`, `BrainHealthEngine`, `BlockingEngine`, the provider
protocol, `MockScreenTimeProvider`. Golden unit tests for the health model.
*Exit: `swift test` green, model provably matches `04-BRAIN-HEALTH.md`.*

### Phase 2 — Authorization + selection **[DEVICE]**
`AuthorizationCenter` flow with refused/revoked handling. `FamilyActivityPicker`,
persisted selection, `Label(token)` rendering, token-rotation remapping.
*Exit: pick Instagram on device, see it listed after relaunch.*

### Phase 3 — Shield one app **[DEVICE]**
`ManagedSettingsStore` named stores, block now / unblock, custom `ShieldConfiguration`,
`ShieldActionDelegate` writing to the App Group.
*Exit: Instagram will not open; our block screen appears; the counter increments.*

### Phase 4 — Monitoring + the threshold ladder **[DEVICE]**
`MushMonitor`, schedules, the ladder, the L10 defensive validator, temporary-access
grants via event thresholds.
*Exit: real usage produces real rungs in the ledger; a 5-minute grant expires correctly.*

### Phase 5 — Limits, schedules, focus
Daily budgets, recurring windows (bedtime/morning/work), focus sessions and Pomodoro.
*Exit: a budget shields the app on its own; a bedtime window fires unattended.*

### Phase 6 — Statistics
Our-ledger charts, the embedded `DeviceActivityReport` scene, provenance marking,
7-day vs prior-7-day comparison.
*Exit: Stats reads truthfully on both planes with the mock and, later, on device.*

### Phase 7 — Brain system + UI pass
The character and its five states, transitions, the Receipt screen, streaks,
achievements. **This is where the design system gets built** — aesthetic direction is
committed to `brand/brand.json` first, then tokens, then screens. Never inline values.
*Exit: anti-slop gate and the deterministic detector both pass; screenshots from CI.*

### Phase 7.5 — Competitive parity
Scrape Opal and Brainrot feature by feature, classify every one, build the missing
ones that public APIs allow: rule groups, allow-list mode, frequency limits, gems,
milestone nudges, the weekly digest, the widget, the Live Activity, Shortcuts intents
and the maintenance repairs. Recorded in `10-FEATURE-PARITY.md`.
*Exit: no competitor feature is unaccounted for — every one is HAVE, ADDED, SPEC,
LATER, NO or IMPOSSIBLE, with the reason written down.*

### Phase 8 — Interventions
Shield-based intervention copy per strictness level; Shortcuts automation onboarding
(App Intent + guided setup); the local-notification fallback with its caveats surfaced.
*Exit: opening a watched app produces the intended friction.*

### Phase 9 — Feed Quarantine
Clean Feed `WKWebView` + `WKContentRuleList`, the versioned rules asset, the Safari web
extension, drip mode. Ordered last on purpose — it is the differentiator, but it is
worthless before the blocking engine is trustworthy.
*Exit: Instagram web loads in Clean Feed with Reels genuinely absent.*

### Phase 10 — Device hardening **[DEVICE]**
Answer Q1–Q4 from `01-FEASIBILITY.md`. Battery behaviour, extension memory, threshold
accuracy on the real iOS 26.x build. Fix what the real device disproves.

---

## Ordering rationale

Two things are deliberately late:

- **UI polish (7)** sits after statistics because polishing screens whose data model is
  still moving is wasted work.
- **Feed Quarantine (9)** sits after interventions despite being the headline
  differentiator, because it depends on the blocking engine being reliable. Shipping a
  clever Reels workaround on top of a shaky shield would be building the roof first.

Two things are deliberately early:

- **The mock provider (1)** because without it nothing is runnable in the current
  account situation.
- **The brain engine (1)** because it is pure logic, fully testable from Windows, and it
  defines the data the ledger must collect — getting it late would force a ledger rewrite.

---

## Current position

Phases 0, 1, 6, 7 and 7.5 are done. Phases 2, 3, 4 and 10 are **blocked** on the Apple Developer
membership; everything up to and including Phase 9 can be built and demonstrated in the
Simulator without it.
