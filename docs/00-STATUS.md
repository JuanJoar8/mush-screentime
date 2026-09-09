# 00 · Status — read this first

**Project:** MUSH — an iOS Screen Time app whose brain-blob character reflects your
relationship with distracting apps.
**Target:** iPhone 16 Pro, iOS 26. Native Swift 6 / SwiftUI.
**Last updated:** 2026-09-08

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

## The character, and where to look at it

The creature was rebuilt on 2026-09-08. It had been a flat sticker — solid fill, one
heavy contour, folds as thin lines. It is now **modelled**, and the distinction that
matters is *where the volume comes from*: not a radial gradient over a smooth egg, which
is what the version before the flat one was and why that one was killed. Each gyrus is a
ridge drawn as four strokes on one curve, all offset along a single light vector — a dark
groove pushed away from the light, the ridge body, a lit crest, and a specular pop that
only fires on the folds near the light. The two global gradients say where the light is;
the folds do the describing.

Two new parameters carry the material, and they are the reason a stage is a *condition*
rather than a mood:

| | crisp | foggy | buzzed | melting | mush |
|---|---|---|---|---|---|
| folds / side | 16 | 12 | 9 | 4 | 2 |
| `turgor` | 1.00 | 0.72 | **0.86** | 0.44 | 0.22 |
| `gloss` | 1.00 | 0.46 | **0.78** | 0.20 | 0.06 |
| `necrosis` | 0.00 | 0.14 | 0.30 | 0.68 | 1.00 |
| `translucency` | 1.00 | 0.62 | 0.40 | 0.14 | 0.00 |
| `film` | 0.00 | 0.22 | 0.66 | **0.84** | 0.58 |

**Three of the six axes break the ladder on purpose, each for its own reason.** `gloss`
and `turgor` both peak at buzzed: overstimulated is neither dull nor soft — it is the most
awake the creature ever looks and the worst it is doing, and a wired brain holds its folds
harder than a hazy one that has already started to give. `film` breaks at the other end
instead (see below). `materialAxesAreDeliberate` pins the exact shape rather than a
direction, so a tidy-up into a clean descent fails the build and says why.

**The turgor peak cost a day of red CI, and how it did is worth keeping.** The commit that
rebuilt the creature (`f84a006`, 2026-09-08) shipped a test asserting turgor was monotonic
*and* a table putting buzzed above foggy — in the same commit, contradicting each other,
and nobody watched the run. Worse, the repo argued both sides: this file bolded only
`gloss` as the exception, while `gloss`'s own doc comment said foggy "has already gone
soft", which is a claim about turgor. Resolved 2026-09-09 in favour of the data: buzzed is
tense. The two axes now say the same thing about that stage instead of opposite things.

That is the failure mode this project already had a rule for, arriving from a new
direction: **a green check does not say the thing works — and a check nobody reads does not
say anything at all.** Both this repo's other guard failures were checks measuring the
wrong thing. This one measured the right thing, said so, and was not read for a day.

**Three more axes landed on 2026-09-08, and they are what make the ladder a pathology
rather than a dimmer.** The five stages had been separable — sixteen folds versus two is
not a subtle difference — but everything below `foggy` still read as *sad*, and everything
above it read as *the same creature, brighter*. Neither is what the product is about.

- **`necrosis`** is rot, and it has to do three things at once or it is just a darker
  fill. It stains the body in **uneven patches** — a field of equal-weight spots is a
  texture, and a texture reads as material rather than as disease. It collects in the
  **sulci before the ridges**, because a groove is the low point of the surface and that
  is where decay pools. And it **eats the contour**: past 0.02 the outline stops being one
  even stroke and becomes 46 arcs whose weight and darkness vary along the curve, so it
  thins to nothing in places. A continuous even outline is the last thing holding a
  rotting body together, and for exactly that reason the last thing that makes one read as
  drawn rather than as decaying.
- **`translucency`** is subsurface scattering, and it is the entire "superior" half. It is
  drawn **red whatever the body's colour**, because what the light passed through is blood;
  it sits on the side **away** from the key, because that is the side the light had to
  cross the body to reach; and it is brightest where the body is **thinnest**, so it hugs
  the contour instead of pooling in the middle. Composited with `plusLighter`, which is
  what transmitted light does. There is no substitute for it: a specular says the surface
  is wet, and only transmission says there is something alive behind the surface. `crisp`
  cannot be reached by turning `gloss` up.
- **`film`** is the third kind of wet and **dips at the bottom**, which is the point.
  `melting` is actively liquefying and is the greasiest the creature ever gets; `mush` sits
  well below it because by then the thing has dried out. Past a certain point decay stops
  being wet. A ramp straight to the bottom would say the opposite, so
  `rotAndVitalityAreSeparateReadings` asserts the dip.

**A second pass on 2026-09-09 took the material out to the parts that were still flat.**
Three axes on the body only left the body modelled and everything hanging off it not.

- **The limbs were the most conspicuous unmodelled thing left** — four constant-width
  strokes, identical across all five stages but for their angle, which read as clip art
  bolted onto a rendered head. They now taper (a limb is thicker at the root; constant
  width is a wire), they rot with the body, and they **transmit at the tip**. That last
  one is the physically correct half and the one that sells it: subsurface scattering is
  strongest where the body is *thinnest*, which is why a hand held to a lamp glows red at
  the fingers and stays opaque at the palm. The glow is gated on distance along the limb,
  `u^2.2`, so it stays off the shoulder. Sprinkled evenly it is a coloured outline.
- **The cast shadow is not neutral grey under a translucent body.** Light crosses the
  body, picks up its colour and lands on the floor inside the shadow — the reason shade
  under a hand on a lit table is warm and shade under a stone is not. The soft outer pool
  carries it; the contact core stays neutral, because nothing gets through at the point of
  contact. The core also hardens with necrosis: an opaque mass sits more heavily than a
  lit one.
- **The sclera yellows.** A surgical-white eye on a body that is coming apart is the one
  detail that undoes every other one.

The taper is inward only, so `Reach.limbCap` can only shrink. `check-fit.js` measured the
prediction rather than taking it: the tightest margin stayed at 4.5px and the horizontal
extents *contracted* — `mush` went from 71.4→370.0 to 72.5→368.9.

Two things were deleted rather than left beside the new ones, per housekeeping rule 2: the
old two-stroke `stroke(_:_:_:_:)` helper, whose only caller was the untapered limb, and the
doc comment describing that drawing.

**The silhouette erosion is subtractive by construction, and that is a hard constraint
rather than a style choice.** `Reach` is derived from the un-eroded curve, so a body that
can only shrink cannot push the drawing past its canvas — no rederivation, no fit risk.
`check-fit.js` confirms it: the tightest margin anywhere is unchanged at 4.5px. The two
times this creature has been clipped off the edge of its frame, both started with someone
growing a shape and then reasoning about the budget on paper.

**The review sheet is published as an artifact:**
<https://claude.ai/code/artifact/1443e5ab-9c31-409b-9e48-92374b1c4380> — five stages live,
the drawing pipeline stopped at each of its four layers, and three app screens. The URL changed on 2026-09-08: the sheet is a **build output**, not a source, so a new
one costs nothing and the old dark-theme sheet is superseded rather than lost. Rebuild it
with `python scripts/build-mockup.py`, which splices the renderer out of `host/console.html`
so the sheet cannot drift from what ships, then republish to that same URL.

**One token was retired, not recoloured.** `primary` was `#7C5CFA` — hue 252, saturation
94%, squarely inside the forbidden purple band, and flagged by `anti-slop-gate.sh` the
first time that gate was ever actually run against this repo. No Swift view consumed it;
its only reader was the host console's focus ring, which now uses `accent`. A dead token
that also breaks the one colour rule the project has is not a value to tune.

---

## Environment

- Owner is on **Windows 11**. No Mac, no Xcode locally.
- Builds happen on **GitHub Actions `macos-26`** (Xcode 26, iOS 26 SDK).
- Device installs, once unblocked, happen from Windows via `ideviceinstaller`.

---

## Progress

| Phase | State |
|---|---|
| 0 · Foundation | **done** — 8 targets, XcodeGen, CI green on tests |
| 1 · Domain core + mock | **done** — 88 tests passing on CI |
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

**Everything not marked blocked is done.** As of 2026-09-08 there is no remaining product
work that does not need either the $99 membership or a physical iPhone. The next move is
not a commit; it is one of those two things.

### What a device would answer immediately

- **Q10b** — do the `css-display-none` selectors match the markup a *signed-in* Instagram
  shows? CI has no account. This is the one that decides whether Clean Feed is a product
  or a demo.
- **Q8** — does `openParentalControlsApp` open our app or Settings?
- Whether Safari accepts the content blocker's rule list. Layer 2 proves WebKit's
  compiler does; Safari's own is untested.

---

## Guards, and what each one actually looks at

| script | what it measures | what it cannot see |
|---|---|---|
| `check-plists.py` | every extension `Info.plist` has the six keys the embed step needs | whether the extension does anything |
| `check-console.js` | the host page's script runs, all five stages draw, gradients and curves are present | whether the result looks like a brain |
| `check-fit.js` | **the bounding box of everything drawn, against the canvas**, for all five stages | anything inside a `clip()`, by design — the clip path is what bounds those, and it is measured |
| `check-folds.js` | **how many folds each stage actually draws**, against the number its table declares | whether a drawn fold is in a sensible place — only that it exists |
| `check-workflow.py` | the CI YAML parses and its steps are shaped right | whether the steps assert anything |
| `screen-not-blank.swift` | pixel variance in a screenshot, cropping the status bar and home indicator | a crash: the springboard has high variance too, hence the separate crash-report gate |

### The blank-screen guard has now failed open three times

Each time it reported `ok` on a screen that rendered nothing, and each time for a
different reason. This is the guard the project's first lesson was written about, and it
keeps re-earning it.

1. **ImageMagick was not on the runner.** Every image reported `sigma=-1`, every one was
   skipped, the build went green.
2. **The threshold read iOS, not the app.** A screen showing nothing but the status bar
   scored 6.70 against a threshold of 6. Fixed by cropping the top 9% and raising the bar
   to 10.
3. **NaN, on 2026-09-09.** `sumSquares / n - mean * mean` is algebraically the variance
   and numerically is not: on a uniform image the two terms are equal, and in floating
   point the subtraction lands a few ulps *below* zero. A uniform field at luma 17.353 —
   an ordinary near-black screen — computes `-1.4e-11`, and `.squareRoot()` of a negative
   Double is NaN. Every comparison against NaN is false, so `sigma < threshold` was false
   and the verdict printed `ok`. **Three blank screens shipped green reading
   `sigma=nan  ok`: brain, gallery and setup.**

Fixed twice over, because the cause and the shape are different bugs. The variance is now
a two-pass sum of squared deviations, which cannot go negative. And the verdict is written
`sigma >= threshold` rather than `sigma < threshold`, so a screen passes only by clearing
the bar — never by failing to fall below it. Anything non-finite is reported and fails.

**And the same bug was breaking the retry loop, which is what actually blanked the
screenshots.** The capture step takes a shot, asks the guard whether it rendered, and
retries up to five times if not — the whole point being that a screen drawing five
creatures may not have presented a frame in three seconds. `notblank` exits 0 for NaN, so
the loop *broke on the first attempt* for exactly the screens that needed the retry, kept
the blank shot, and printed `rendered after 3s`.

So one arithmetic error did two things: it disabled the retries that exist for slow first
frames, and then waved through the blank frames that resulted.

**All seven screens render now**, and it is reproducible rather than lucky — two
consecutive runs of `c7e4b33` produced identical measurements to the decimal:

| screen | sigma | | screen | sigma |
|---|---|---|---|---|
| home | 31.39 | | brain | **16.22** |
| blocks | 26.02 | | gallery | **33.26** |
| stats | 18.18 | | setup | **17.50** |
| cleanfeed | 52.94 (after 6s, on the second attempt) | | | |

The three in bold had been shipping black since at least 2026-09-08. Nothing was wrong
with `BrainView`, `StageGalleryView` or `PathBSetupView`: they were slow to present, which
is the case the retry loop was written for and the case the guard's NaN had removed.

`cleanfeed` still needs a second attempt every run. That one is real: it compiles a
`WKContentRuleList` before it can draw. It is not a bug, but it is the reason the retry
loop must keep working.

## Sixteen folds a side was not true

Unblocking the gallery made the creature visible for the first time, and the first thing
it showed was that the folds barely read: a few scratches on the crown and a smooth field
everywhere else. Counting them, on 2026-09-09:

| stage | declared | drawn | survival |
|---|---|---|---|
| crisp | 32 | 14 | 44% |
| foggy | 24 | 10 | 42% |
| buzzed | 18 | 8 | 44% |
| melting | 8 | 4 | 50% |
| mush | 4 | 2 | 50% |

**Every stage was losing more than half.** `crisp` declares sixteen a side and drew seven
— and "sixteen a side" is written in `CreatureParameters`, in this file, and on the review
sheet. Three statements of a number that nothing measured.

Two causes, neither of them visible in a screenshot:

- **The keep-out was a box.** It spanned the glasses' width and ran from the brows to the
  bottom of the body, so it took the four corners a face does not occupy and the entire
  belly below the mouth — the widest part of the creature, which had never carried a
  single fold. It is an ellipse now, sized to the features it has to miss.
- **A fold that landed on the face was dropped.** That is the part that made the count a
  lie rather than a layout quirk. Folds are pushed clear of the face now, then clamped
  inside the silhouette — a fold shoved past the edge is clipped away, which is the same
  loss by a quieter route.

The lens shrank with it, `radius * 0.42` → `0.35`. At 0.42 the glasses covered most of the
frontal surface, which is exactly where a brain's folds are, and the creature read as a
smooth roll wearing goggles. It was also written as a bare literal in two places that had
to agree by hand; it is `Reach.lens` now, in one.

All five stages draw 100% of their declared folds, and **`check-folds.js` is what says
so** — verified to fail, at exit 2, against a copy of the drawing with the old
drop-instead-of-move behaviour. A guard that has never been seen to fail is the shape of
the last three failures in this repo.


`check-fit.js` is new on 2026-09-08 and it is the **third** guard against one bug. The
creature has been drawn past the edge of its canvas twice — a glove that grew past a
hardcoded fraction, then fit arithmetic redone for `crisp` and never rechecked against
`mush`, which spreads 16% wider. Both times the fix was "derive `Reach` from the constants
the drawing uses". Both times the derivation was itself done by hand, which is a claim and
not a check. This one runs the drawing and measures. Tightest margin today: 6.8px, on the
top of the `crisp` thumbnail, where a sparkle sits.

It found one thing on its first run that no screenshot would have: `Reach.finger` measured
the fingertip's *centre*, not the round cap of the stroke that draws it — half a line width
past the budget. Latent, because height binds the fit at every size the app uses, but the
fit is written as a guarantee for any frame. `Reach.limbCap` closes it.

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
