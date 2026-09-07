# 02 · Product specification

## Identity

**MUSH** — *don't let it turn to mush.*

Original product, original character, original naming. We reproduce the behavioural
concept of the category (a creature whose condition mirrors your relationship with
distracting apps) and none of anyone else's artwork, copy, screens, or branding.

The character is a **brain-blob**. Not a medical illustration and not a cute mascot with
a lanyard — something with the physical logic of a gel that holds its shape when it is
firm and slumps when it is not. Its five states are named off the product name:

**Crisp → Foggy → Buzzed → Melting → Mush**

`Buzzed` sits deliberately in the middle and is the *most agitated* state, not a
midpoint between alert and asleep. See `04-BRAIN-HEALTH.md` section 4.

### Voice

Dry, specific, slightly absurd. Never clinical, never scolding, never a wellness
platitude. It states facts about your day and lets them land.

- Good: *"41 minutes. Under budget. It's holding shape."*
- Good: *"You opened this 14 times today. It knows."*
- Banned: *"Great job!"*, *"Let's build better habits together"*, *"You've got this!"*,
  streak-loss guilt, anything with "journey" or "mindful" in it.

---

## 2. The loop, and where each screen sits in it

```
behaviour -> measured -> health changes -> visual feedback
   ^                                            |
   |                                            v
reward/streak <- recovery <- less distraction <- intervention
```

| Loop stage | Surface |
|---|---|
| measured | threshold ladder (invisible) |
| health changes | Home: the character + the number |
| visual feedback | character state, live provisional delta |
| intervention | shield screen, Clean Feed fork, focus session |
| recovery | Receipt screen — *why* it moved |
| reward | streak, stage-up, cosmetic unlock |

Nothing ships that does not sit on this diagram.

---

## 3. Information architecture

Four tabs. Home carries the loop; the rest are depth.

```
Home            the character, health, today, the one primary action
Blocks          what is blocked, limits, schedules, focus
Stats           our ledger  +  Apple's report (provenance-marked)
Brain           stages, streak, achievements, cosmetics, the Receipt
```

Settings lives inside Brain rather than as a fifth tab — it is small and mostly
strictness configuration.

### Home hierarchy

The brief proposed: character → health → today's distracting time → status → primary
action → limits → progress/streak. I am changing two things:

1. **Health number and character are one unit, not two rows.** The number floats on the
   character. Two separate rows say the same thing twice and cost the fold.
2. **The primary action moves up, directly under the character.** In a self-control app,
   the moment of intent is fragile. The button that starts a focus session or blocks
   everything now should be reachable before the user has read anything.

Resulting order:

```
1  Character + health, as a single object      <- state in under a second
2  Primary action (contextual)                 <- act on it immediately
3  Today: distracting minutes vs budget        <- the one number that drives C1
4  Active blocks / next scheduled window
5  Streak + provisional delta
```

The primary action is **contextual**, not fixed:

| Condition | Button |
|---|---|
| under budget, nothing active | Start focus |
| over budget | Block everything |
| focus running | End session (with the timer as the button) |
| scheduled window active | Shows the window, no action |
| authorization missing | Fix Screen Time access |

---

## 4. MVP scope

**In** (this is what "working" means):

1. Screen Time authorization + a real fallback when it is refused or revoked
2. `FamilyActivityPicker` selection, persisted, re-mappable across token rotation
3. Block now / unblock, on real app + category tokens
4. Daily limit per selection group, enforced by the threshold ladder
5. One recurring schedule type, proven end to end (bedtime), then generalised
6. Focus session + Pomodoro, enforced by the monitor extension
7. Custom shield screen with a working temporary-access grant
8. `UsageLedger` and the shield/override counters
9. `BrainHealthEngine` with the full model in `04` and its golden tests
10. Home / Blocks / Stats / Brain, with the mock provider driving everything
11. Stats: our ledger charts + the embedded Apple report

**Out of MVP, deliberately sequenced later:**

- Feed Quarantine layers 2–4 (Clean Feed browser, Safari extension, drip mode)
- Shortcuts automation onboarding
- Cosmetics and achievements beyond the streak
- Any remote sync — the app is local-only and stays that way

**Never:** accounts, analytics SDKs, cloud upload of usage data. All processing is
on-device, which is not a marketing line here but a structural fact — the interesting
data physically cannot leave the report extension anyway.

---

## 5. Strictness levels

| Level | Shield override | Cost |
|---|---|---|
| **Gentle** | secondary button, one tap, 5-min usage grant | C3 penalty |
| **Standard** | grant requires completing an intervention in-app first | C3 penalty |
| **Strict** | no override button; the shield stands until the window ends | — |
| **Sealed** | strict, plus we hide our own unblock controls behind a delay | — |

**Honest limit, stated in the UI at the point of choosing:** no level is unbreakable.
iOS gives third-party Screen Time permission no passcode protection (L7) — the user can
revoke it in Settings with one toggle, and nothing we ship can prevent that. "Sealed"
raises friction; it does not lock a door.

---

## 6. Statistics — the two-tier contract

The user sees both, clearly separated by provenance, because we are structurally unable
to merge them:

**Ours (computed, explainable, drives everything):**
distracting minutes by ladder rung · budget ratio · limits reached · shields shown ·
overrides taken · grants used · focus sessions started/completed · focus minutes ·
schedule adherence · streak · brain health history · 7-day vs prior-7-day improvement

**Apple's (rendered by the report extension, display-only, marked with a provenance
chip):** total screen time · per-app duration · per-category duration · web domain
activity · pickups · notifications received

We will never present an Apple-sourced number as an input to brain health, and never
present a ledger number as if it were Apple's ground truth. The `01` doc explains why
that boundary exists; the Stats screen explains it to the user in one line.
