# 10 · Feature parity — Opal and Brainrot, feature by feature

Scraped 2026-09-07 from the two products' own surfaces: `opalapp.com/features`,
`opal.so/features`, Opal's help centre, Brainrot's FAQ, and both App Store listings.
Marketing pages are the source; App Store copy is the cross-check. Where the two
disagree I take the help centre over the marketing page.

This document exists to answer one question mechanically: **is there anything those two
apps do that MUSH does not?** Every row ends in a status, and no row is allowed to say
"partially".

| Status | Meaning |
|---|---|
| `HAVE` | Already in `MushKit` or the app, before this pass |
| `ADDED` | Added in this pass — code and tests in the repo |
| `SPEC` | Fully specified, cannot run until the Family Controls entitlement exists |
| `LATER` | Feasible, deliberately sequenced later, with the phase named |
| `NO` | Refused on purpose. The reason is in the row |
| `IMPOSSIBLE` | No public iOS API does this. Named alternative in the row |

---

## 1. Opal

| # | Opal feature | Status | MUSH equivalent |
|---|---|---|---|
| O1 | **Opal Score / Focus Score** — one daily number | `HAVE` | Brain Health 0–100. Ours is *explainable*: every point is a `Contribution` with a reason string, shown on the Receipt. Opal never says how its number was produced |
| O2 | **Score history** | `HAVE` | `LedgerState.entries`, one `HealthEntry` per day, with before/after and the full contribution list |
| O3 | **Focus Rules** — block chosen apps | `SPEC` | `FamilyActivitySelection` + named `ManagedSettingsStore`. Phase 3 |
| O4 | **Focus Timer** — pick a length, locked until it ends | `HAVE` | `FocusSession`, enforced by the monitor extension |
| O5 | **Pomodoro** | `HAVE` | `FocusSession.Kind.pomodoro` / `.breakInterval` |
| O6 | **Blocking difficulty: Normal / Timeout / Deep Focus** | `HAVE` | `Strictness`: gentle / standard / strict / sealed. Four levels, and each states its own honest limit |
| O7 | **Allow Only / Allow List** — block everything *except* a chosen set | `ADDED` | `BlockMode.allowlist` → `store.shield.applicationCategories = .all(except:)`. See §3.1 |
| O8 | **Unlimited Rules** — many independent rule sets | `ADDED` | `RuleGroup`, an array. Each carries its own selection, budget, windows, strictness and mode |
| O9 | **Time Limits** (daily allowance per app) | `HAVE` | Threshold ladder + `DayRecord.budgetMinutes` |
| O10 | **Open Limits** (cap how many times you open something) | `ADDED`, renamed | `FrequencyLimit` — a cap on **quarter-hours touched**. Not an open count, and never labelled one. See §3.2 |
| O11 | **Recurring sessions / calendar of focus hours** | `HAVE` | `ScheduleWindow` with weekdays and midnight wrap |
| O12 | **Sleep routine** | `HAVE` | A `ScheduleWindow` that crosses midnight. Same primitive, different name |
| O13 | **Streaks** | `HAVE` | `LedgerState.streak`, advanced on green days only |
| O14 | **Focus Gems** — collectible milestones | `ADDED` | `Gem` catalogue, 12 entries, each with a deterministic predicate over the ledger. No random drops. Delivered, not merely computed: `GemShelf` on the brain screen and a `GemUnlockOverlay` at the moment one fires. The first evaluation backfills an existing history **silently** — eight gems at once on first launch is noise, and it devalues the ninth |
| O15 | **Widgets, Home and Lock Screen** | `ADDED` | `MushWidget`, three families, reading `WidgetSnapshot` from the App Group |
| O16 | **Live Activities on the Lock Screen** | `ADDED` | `FocusActivityAttributes`. Self-driving countdown — see §3.3 for why it cannot be updated from the monitor |
| O17 | **Mindful block screens with quotes** | `SPEC` | `ShieldConfiguration`. Ours carries the live health delta instead of a quote — the cost is the message |
| O18 | **Mini-games in waiting rooms** | `ADDED` (as intervention) | `Intervention` — the thing `Strictness.standard` demands before it issues a grant. Ours is a 20-second hold, not a game: a game rewards the interruption |
| O19 | **Weekly report** | `ADDED` | `WeeklyDigest` — 7 days vs the prior 7, with the biggest single mover named |
| O20 | **Soundscapes** | `ADDED` | Four, and none of them is a file. `NoiseGenerator` synthesises brown, pink and a six-second tidal swell a sample at a time on the audio thread; the maths lives in `MushKit` so it is unit-tested rather than listened to and hoped about. A loop long enough not to be noticeable is tens of megabytes, and a short one is worse than silence because the ear finds the seam. Generated noise has no seam |
| O21 | **Leaderboards / challenge friends** | `NO` | Needs an account and a server. `02-PRODUCT.md` §4 says never, and that is a structural promise, not a preference |
| O22 | **Desktop app** | `NO` | Out of scope. The brief says iPhone 16 Pro |
| O23 | **Focus Mode / Shortcuts integration** | `ADDED` | `StartFocusIntent` / `EndFocusIntent` / `LogAppOpenIntent`, all `openAppWhenRun = false`. This is also Path B's measurement spine (`09-PATH-B-NO-ENTITLEMENT.md`) |

## 2. Brainrot

| # | Brainrot feature | Status | MUSH equivalent |
|---|---|---|---|
| B1 | **Brain avatar that decays and heals** | `HAVE` | `BrainStage` × `BlobView`. Five states, every visual parameter derived from the stage rather than hand-picked |
| B2 | **Health score against a daily goal** | `HAVE` | `budgetContribution(ratio:)`. Same idea, and ours publishes the curve |
| B3 | **Customisable daily goal** | `ADDED` | `RuleGroup.budgetMinutes`, per rule group, stored per day so history stays truthful when it changes |
| B4 | **Instant block, apps and websites** | `SPEC` | `shield.applications` + `shield.webDomains`. Phase 3 |
| B5 | **Category blocking** | `SPEC` | `shield.applicationCategories = .specific(_:except:)` |
| B6 | **Website blocking** | `SPEC` | `shield.webDomains` / `webDomainCategories` |
| B7 | **Daily time allowances** | `HAVE` | Threshold ladder |
| B8 | **Smart schedules — bedtime, mornings, meetings** | `HAVE` | `ScheduleWindow` |
| B9 | **Multiple independent rules by day/time** | `ADDED` | `RuleGroup` (same row as O8) |
| B10 | **Trigger before "one quick scroll"** | `HAVE` | Rung 1 of the ladder fires at the first minute. That *is* the mechanism |
| B11 | **Focus timer + Pomodoro** | `HAVE` | `FocusSession` |
| B12 | **Mindful breaks** | `HAVE` | `FocusSession.Kind.breakInterval` |
| B13 | **Block screen with the character on it** | `SPEC` | `ShieldConfiguration` renders the stage |
| B14 | **Home screen widget with today's score** | `ADDED` | `MushWidget` (same row as O15) |
| B15 | **Nudges at 75 / 50 / 25 / 10 % of score** | `ADDED` | `MilestoneWatcher`, with hysteresis so a number hovering on a boundary cannot spam. They now actually leave the app: `MushNotifier` posts them under provisional authorisation, silently, and every notification is deferred past the first refresh so a launch cannot fire a backlog |
| B16 | **Usage breakdown on the main view** | `HAVE` | Home's hour ribbon + Stats. Ours separates our ledger from Apple's report by provenance; Brainrot presents one merged surface it cannot actually justify |
| B17 | **Multi-device sync over the same Apple ID** | `NO` | Usage data never leaves the device. `NSUbiquitousKeyValueStore` could carry *settings* only; not worth the second source of truth for one phone |
| B18 | **Refresh, to fix blocking that got stuck** | `ADDED` | `MaintenanceAction.reapplyShields`. Real need — FB14237883 leaves stale shield UI after a store migration |
| B19 | **On-device processing** | `HAVE` | Structural here, not a claim: the interesting data physically cannot leave the report extension |

---

## 3. The three additions that needed an API check first

Everything in the `ADDED` rows above is either pure logic or a framework we already use.
Three were not obvious and were verified before a line was written.

### 3.1 Allow-list — `ActivityCategoryPolicy.all(except:)`

`ShieldSettings.ActivityCategoryPolicy` has a real `all(except:)` case. So Opal's
"Allow Only" is reachable:

```swift
store.shield.applicationCategories = .all(except: allowed)   // allowed: Set<ApplicationToken>
```

Two constraints came with it, and both change our architecture:

1. **A store cannot make another store less restrictive.** Once any store sets `.all()`,
   no other store can carve an exception out of it. That collides head-on with D4
   ("one `ManagedSettingsStore` per concern"): an allow-list group cannot be one store
   among several. It has to own the whole shield surface while it is active.
   → **D16** records the resulting rule: allow-list mode is exclusive. Turning it on
   suspends every other group, and the UI says so before the switch flips.
2. There are open reports of exempted apps still being shielded under `.all(except:)`.
   Unverified by us — no device. It goes in `01-FEASIBILITY.md` as **Q5**, not in the UI
   as a promise.

### 3.2 Open Limits — what we can actually count

Opal caps *opens*. iOS gives no public open/pickup count outside the report extension,
and the report extension cannot export a number (L2). So an exact open limit is
`IMPOSSIBLE`.

What we can count is **rung-1 firings**: the ladder's first threshold is one minute of
usage, so each firing means "a session that reached a minute". That undercounts — a
15-second glance never fires — and it cannot distinguish one 40-minute sitting from
40 one-minute ones without the timestamps, which we do have.

So `FrequencyLimit` caps **quarter-hours touched** — how many 15-minute slices of the
day had this app in them — and the UI uses those words. It is never labelled "opens" or
"pickups".

It is a floor, and deliberately so: a quarter-hour of use that never crosses a threshold
is not counted, so we can say "at least 9", never "9". Undercounting in the user's favour
is the honest direction to be wrong in.

What it genuinely cannot do is tell one long sitting from several short ones: an hour
straight and four scattered five-minute dips both touch four quarter-hours. It measures
how much of your day the app is present in, which is a real second axis next to duration
— but it is not fragmentation, and the copy does not imply it is.

### 3.3 Live Activity — starts in the foreground, then drives itself

`Activity.request(...)` only works with the app in the foreground, and an app extension
cannot reliably reach the activity list. A focus session starts on a tap, so starting is
fine. Ending is the problem: the session ends while the phone is in a pocket.

The design that survives this: **the Live Activity never needs an update.** It ships the
end date in its `ContentState` and renders with `Text(timerInterval:)`, which counts down
on its own, plus a `staleDate` at the end and `.after(...)` dismissal. The monitor
extension does not touch it. If the user reopens the app, the app reconciles.

Same shape for the widget: `WidgetCenter.reloadAllTimelines()` from the monitor is
budgeted and may be deferred, so the widget's timeline carries several future entries and
degrades to "as of HH:MM" rather than lying about being live.

---

## 4. What MUSH has that neither of them has

Not parity — these are the reasons to build it at all.

1. **The Receipt.** Every point of the score traced to a named cause. Opal's score is a
   black box; Brainrot's is a ratio it does not show you.
2. **Provenance separation.** Apple's numbers are marked as Apple's and are structurally
   barred from touching the health model. Both competitors present one undifferentiated
   surface.
3. **Blind days are drawn hollow.** A day the monitor never woke is not a zero and is not
   green. Nobody else distinguishes "you used nothing" from "we saw nothing".
4. **Feed Quarantine.** Reels and Shorts removed at path level inside our own WebView —
   the thing neither app attempts, and `05-SHORTS-REELS.md` says plainly why it cannot be
   done inside the native apps.
5. **Path B.** The app degrades to a working product with no Family Controls entitlement
   at all. Both competitors are dead without it.

---

## 5. Deliberate non-features, and why

| Not building | Reason |
|---|---|
| Leaderboards, friends, challenges | Requires an account. Structural promise in `02-PRODUCT.md` §4 |
| iCloud sync of usage | Same. Settings-only sync is possible and still not worth a second source of truth |
| Mini-games behind the shield | The waiting room should be boring. A game rewards the interruption it is meant to discourage |
| Motivational quotes on the shield | The block screen shows what this costs you in points. That is more specific than a quote and it is true |
| "Saves you 2 hours a day" style claims | We cannot measure total screen time (L2). Claiming a saving we cannot compute is the exact thing `anti_slop.forbidden_patterns` forbids |
