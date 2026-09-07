# 04 · The Brain Health model

Design constraint: **deterministic, explainable, and computable from data we are
actually allowed to have.** The user must always be able to open one screen and see the
exact arithmetic behind today's change. No hidden weights, no ML, no vibes.

Everything here is computed from **our own ledger** (threshold-ladder rungs, shield
events, focus sessions), never from Apple's report data — which we are not permitted to
read (see `01-FEASIBILITY.md` section 3).

---

## 1. The state variable

`brainHealth: Double` in `[0, 100]`. Starts at **70** on first run — deliberately not
100, so the very first good day is rewarded rather than merely preserving a perfect
score.

Health changes **once per day**, at the day rollover, by a single signed delta:

```
BH(d+1) = clamp(BH(d) + Δ(d), 0, 100)
```

Between rollovers the UI shows a live **provisional** delta so the character reacts
during the day, but only the rollover commits.

---

## 2. The daily delta

`Δ(d)` is the sum of six contributions, each individually capped, then clamped as a
whole to `[-20, +15]`.

Let `r = distractingMinutes(d) / dailyBudgetMinutes` — the **budget ratio**.

### C1 · Budget adherence — range `[-25, +10]`

Piecewise linear through four anchors, so it can be read off a chart:

| `r` | contribution |
|---|---|
| 0.00 – 0.50 | `+10` (flat) |
| 0.50 – 1.00 | `+10` falling linearly to `0` |
| 1.00 – 2.00 | `0` falling linearly to `-25` |
| above 2.00 | `-25` (floor) |

```
c1(r) = r <= 0.5 ?  10
      : r <= 1.0 ?  10 - 20 * (r - 0.5)
      : r <= 2.0 ? -25 * (r - 1.0)
      :            -25
```

This is the dominant term, which is correct: the product is about time.

### C2 · Focus sessions — range `[0, +9]`
`+3` per completed focus or Pomodoro session, capped at three sessions per day.
An abandoned session scores `0` — never negative. Trying is not punished.

### C3 · Overrides — range `[-10, 0]`
`-2` for each time the user takes the escape hatch on a block screen (the "continue
anyway" / temporary-access path). Capped at five.

Deliberately smaller in magnitude than C1: we penalise *the behaviour*, not the *honesty
of pressing the button*. A user who overrides twice but stays under budget still has a
good day.

### C4 · Schedule adherence — `0` or `+4`
`+4` only if every scheduled block that was supposed to run that day did run, with zero
overrides during those windows. Otherwise `0`. Never negative — C3 already covers it.

### C5 · Streak bonus — range `[0, +5]`
`+1` per three consecutive green days (a **green day** is `r <= 1.0`), capped at `+5`,
i.e. saturating at a 15-day streak. Compounds the habit without letting streaks alone
carry a bad day.

### C6 · Comeback bonus — `0` or `+3`
If `BH(d) < 30` **and** today is green, add `+3`. This exists to break the despair
spiral: a user at rock bottom sees meaningful movement from a single good day instead of
grinding invisibly. Loss-aversion designs that never let you climb back get uninstalled.

### The clamp

```
Δ = clamp(c1 + c2 + c3 + c4 + c5 + c6, -20, +15)
```

Asymmetric on purpose. Worst realistic day is `-20`, best is `+15`, so:

- **100 → 0** takes 5 consecutive maximally-bad days
- **0 → 100** takes 7 consecutive maximally-good days

Decay slightly faster than recovery (it should sting), but recovery is always reachable
inside one week (it should not feel hopeless).

---

## 3. Missing data is never invented

If the Screen Time authorization is revoked, or the monitor extension recorded no rungs
and no shield events for the day, then:

```
Δ = 0,  and the day is marked .noData
```

The day is **not** counted as green, does not break or extend a streak, and is drawn as
a hollow marker in the trend chart. We never guess a number that Apple did not give us,
and we never quietly award a good day for a day we could not see. This is a direct
consequence of L1 and L10 in the feasibility doc — with iOS 26.x threshold regressions,
silently trusting a zero would be actively wrong.

---

## 4. The five stages

| Stage | Range | Character reads as |
|---|---|---|
| **Crisp** | 85 – 100 | alert, firm, bright, quick blinks |
| **Foggy** | 65 – 84 | slightly hazy, slower, still fine |
| **Buzzed** | 45 – 64 | overstimulated — jittery, twitchy, over-saturated |
| **Melting** | 25 – 44 | drooping, losing shape, sluggish |
| **Mush** | 0 – 24 | puddled, barely holding form |

Note the progression is **not monotone sedation**: `Buzzed` in the middle is *more*
agitated than the stages on either side. That matches the actual phenomenology of a
doomscrolling afternoon and keeps the character from being a boring linear dimmer.

### Hysteresis

To change stage you must clear the boundary by **3 points**:

- moving **up** requires `BH >= boundary + 3`
- moving **down** requires `BH <= boundary - 3`

Without this, a score oscillating around 65 would flip the character between Foggy and
Buzzed daily, which reads as broken rather than responsive.

---

## 5. Why the user improved or deteriorated

Every rollover writes a `HealthEntry` recording each contribution **by name and value**,
so the app can render the literal sentence:

> **-9 today.** Over budget by 36 min (-6). Two overrides (-4). One focus session (+3).
> Streak held (+1). Clamped: no.

That receipt is a first-class screen, not a debug view. It is what makes the number
trustworthy, and it is the main thing the reference products get wrong — they show a
score with no derivation.

---

## 6. Gamification bound to the same loop

The rule from the brief: gamification must not be a points system pasted on the side.
So every reward is denominated in the **same currency the model already tracks** — no
separate coin, no XP.

| System | Trigger | Bound to |
|---|---|---|
| **Streak** | consecutive green days | C1 / C5 — the same `r <= 1.0` test |
| **Recovery arc** | climbing a stage boundary | the stage table, section 4 |
| **Achievements** | e.g. *Held the line* (7 green days), *Clean week* (zero overrides), *Deep work* (10 focus hours) | ledger counters already needed for C2/C3/C4 |
| **Cosmetics** | character skins/environments unlocked at stage-up and streak milestones | unlocked by the same events, never purchasable with a parallel currency |

Cosmetics are the only thing that is *purely* decorative, and they unlock on the loop
rather than on a grind, which keeps the incentive pointed at the actual behaviour.

---

## 7. Tuning knobs

All of these live in one struct (`BrainHealthConfig`) so they can be changed in one place
and unit-tested against fixed scenarios:

```
startingHealth       = 70
dailyClamp           = (-20, +15)
budgetAnchors        = (0.5, 1.0, 2.0) -> (+10, 0, -25)
focusPerSession      = +3   (max 3/day)
overridePenalty      = -2   (max 5/day)
scheduleBonus        = +4
streakStep           = 3 green days -> +1  (max +5)
comebackThreshold    = 30, bonus +3
stageHysteresis      = 3
```

`BrainHealthEngineTests` pins the arithmetic with golden scenarios: a perfect day, a
disastrous day, a clamped day, a no-data day, a comeback day, and a stage-boundary
oscillation that must NOT flip.
