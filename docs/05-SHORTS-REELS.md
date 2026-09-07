# 05 · Reels / Shorts — the verdict, and what we build instead

## The short answer

**Selectively blocking Reels inside the native Instagram app, or Shorts inside the
native YouTube app, is impossible on iOS 26 using public APIs. We are not going to
claim otherwise, and we are not going to fake it.**

This is not a gap in my research. It is a structural property of the platform.

---

## 1. Why Android can do it and iOS cannot

one sec ships exactly this feature — *Remove In-App Distractions* — and it is
**Android-only**. Their own documentation says so, in the first person:

> "if you use an iPhone, like myself, right now there's unfortunately no way technically
> to build such a feature on iOS"
> — one sec tutorials, *Remove In-App Distractions (Reels, Shorts, ...) [Android]*

The Android mechanism is **`AccessibilityService`**. An Android app granted that
permission receives a live stream of the foreground app's view hierarchy — node types,
IDs, text, and window state changes — and can act on it, including issuing a Back
gesture. That is enough to detect "the user is now on the Reels view inside Instagram"
and to dismiss it. AppBlock and others use the same mechanism for the same feature.

iOS has **no third-party equivalent**, by design:

- `UIAccessibility` lets an app describe *its own* UI to VoiceOver. It grants no
  read access to another app's view hierarchy.
- Every process is sandboxed. There is no foreground-window-content API, no cross-app
  view introspection, and no synthetic input into another app.
- The Screen Time frameworks operate on **opaque tokens** representing a whole
  application, a whole category, or a whole web host. There is no sub-application
  granularity of any kind.

That is why the feature exists on one platform and not the other. It is an OS
capability difference, not an engineering-effort difference.

---

## 2. Does iOS 26 change anything?

**No.** I checked the Screen Time frameworks for iOS 26 specifically. The notable iOS 26
news for these APIs is *regressions*, not new capability — `eventDidReachThreshold`
firing early and firing with zero recorded minutes on 26.2 and 26.3, widely reported on
the Apple developer forums. No new sub-app targeting, no view-hierarchy access, no
Shorts/Reels-aware API was introduced.

Safari gained user-facing "Distraction Control" (hide an element on a page), but it is a
manual, per-element, user-driven Safari feature — not an API a third-party app can drive.

---

## 3. The four things people confuse with each other

Being precise about this is the whole point, because three of the four **are** possible
and only the fourth is not.

| # | Mechanism | Possible on iOS? | What the user experiences |
|---|---|---|---|
| A | Block the **entire** Instagram / YouTube app | **Yes** | App will not open at all. Blunt but total. |
| B | **Interrupt periodically** — allow the app, then shield it after N minutes of use, requiring friction to continue (one sec's "re-intervention" / doomscroll emergency brake) | **Yes** | Instagram works, then at minute 10 a block screen appears. Not selective — it interrupts *all* Instagram use, not just Reels. |
| C | Block **web URLs** for the short-form feeds | **Yes, but** | Path-level (`/reels`, `/shorts`) works only in **our own WebView and in Safari via an extension**. The `ManagedSettings` web shield is **host-only**, so it can block `youtube.com` entirely but never just `/shorts`. |
| D | **Detect that the user has entered Reels/Shorts inside the native app** and act on it | **NO** | This is the one that cannot be done. |

Most "Reels blocker" claims on iOS are quietly doing A, B, or C and describing it as D.
We will label ours accurately in the UI.

---

## 4. What we build: **Feed Quarantine**

The honest reframing: if we cannot remove Reels from Instagram, we can offer a route to
Instagram that has never had Reels in it, and make that route the path of least
resistance.

Four layers, all public API, all App Store compatible.

### Layer 1 — Shield the native app
`ManagedSettings` shields Instagram / YouTube / TikTok. The block screen does not say
"blocked"; it says **"Reels-free route available"** and points at layer 2.
*Mechanism A, used deliberately as a fork in the road rather than as a wall.*

### Layer 2 — Clean Feed, our in-app browser
A `WKWebView` loading `m.instagram.com` / `m.youtube.com` with a compiled
`WKContentRuleList`:

- `block` rules on `url-filter` patterns matching `/reels`, `/shorts`, `/explore`
- `css-display-none` rules on the Reels tab, the Shorts shelf, and the suggested-video
  rails
- a `WKUserScript` that re-applies removals as the SPA re-renders

Result: real Instagram and real YouTube — DMs, subscriptions, search, posting — with the
infinite short-form surface genuinely absent. **This is the closest thing to the Android
feature that iOS permits, and it actually works**, because it is our web view and we
control the content rules inside it.

### Layer 3 — Safari parity
A Safari Web Extension + Content Blocker so the same rules apply when the user browses
in Safari instead of our app. Proven category — `No Shorts`, `No Reel`, and
`Short Video Hider` all ship this on the App Store today.

### Layer 4 — Drip mode, for when they use the native app anyway
If the user declines the clean route, we do not simply give up. `DeviceActivityEvent`
thresholds shield the native app after N minutes and require friction to resume —
one sec's re-intervention, mechanism B. Labeled in the UI as
*"interrupts all of Instagram, not just Reels"*, because that is what it does.

---

## 5. Honest caveats on Feed Quarantine

Written down so nobody later mistakes this for a solved problem:

1. **DOM fragility.** Layer 2 and 3 depend on Instagram and YouTube markup. Selectors
   will break when those sites change. Rules ship as a versioned JSON asset so they can
   be corrected without an app rewrite. This is ongoing maintenance, permanently.
2. **Login friction.** Instagram web in a `WKWebView` can hit captchas or session
   limits. Unverified at scale. If it degrades, layer 2 weakens and layer 4 carries more
   weight.
3. **Layer 1 and layer 2 may conflict.** See open question Q1 in `01-FEASIBILITY.md`: if
   the Screen Time web-content filter also blocks our own `WKWebView`, then shielding
   `instagram.com` would break Clean Feed. Until that is tested on device, we shield the
   **app token** only and never the **web domain** for any site Clean Feed serves.
4. **It is bypassable.** The user can always open Safari, or revoke Screen Time
   permission entirely (L7). Every layer is friction, not a lock. The product is honest
   about being friction.
5. **Not the Android feature.** A user who wants Instagram-app-with-Reels-removed cannot
   have it on iPhone. From anyone. We say this in onboarding rather than letting them
   discover it after paying attention to us.

---

## 6. What we will NOT do

Ruled out on principle and because they would fail App Review:

- Private APIs or any `SpringBoard` / window-server probing
- A VPN or `NEPacketTunnelProvider` that MITMs TLS to strip Reels traffic. Technically a
  real approach — it is how some network-level Shorts blockers work by filtering the
  `&ctier=SH` parameter — but it requires intercepting the user's encrypted traffic,
  which is a privacy posture we are not going to adopt for a wellbeing app, and Instagram
  certificate-pins anyway.
- Screenshot/OCR polling of the foreground app. Not possible sandboxed, and abusive.
- Accessibility-permission abuse. iOS offers no such surface, and seeking one would be
  the wrong instinct.
- Claiming in marketing copy that we "block Reels" when we mean mechanism A or B.
