# 11 · What iOS 26.4 and 26.5 changed — and what it costs this project

**Read this before `01-FEASIBILITY.md`.** Several statements in that document were true
when it was written and are false on iOS 26.4+. The most important one is the constraint
the entire architecture was designed around.

---

## How this was found, and how sure I am

Not from documentation and not from a blog. The Screen Time frameworks are Swift-only, so
the iOS SDK ships their complete public interface as text. CI on the `macos-26` runner
prints those files and uploads them as a build artifact (`.github/workflows/ci.yml`, job
`kit`).

So the evidence level splits cleanly, and every claim below is tagged:

| Tag | Means |
|---|---|
| **DECLARED** | Copied from the shipped `.swiftinterface`. The declaration exists, with that exact name, type and availability. Not an inference |
| **INFERRED** | My reading of what a declaration is *for*. Reasonable, and could be wrong |
| **UNVERIFIED** | Cannot be settled without a device and the entitlement |

Nothing here has run on hardware. We still have no paid membership.

---

## 1. Usage data can leave the report extension  ⚠️ the big one

**DECLARED** — `DeviceActivity`, iOS 26.4:

```swift
@available(iOS 26.4, *)
extension DeviceActivityData {
    public static func activityData(
        filteredBy filter: DeviceActivityFilter = .init(),
        using policy: DeviceActivityData.Policy = .cached
    ) -> some AsyncSequence<DeviceActivityData, any Error>

    public enum Policy { case cached, live }
    public enum Error: LocalizedError { case unavailable, unauthorized, missingData }
}
```

It is a static function on a public struct. It is **not** confined to a
`DeviceActivityReportScene`, and it carries no annotation restricting it to an extension.

**DECLARED** — what comes back (these payload types are iOS 16, only the accessor is new):

```swift
public struct ApplicationActivity: Hashable {
    public var application: ManagedSettings.Application
    public var totalActivityDuration: TimeInterval
    public var numberOfPickups: Int
    public var numberOfNotifications: Int
}

public struct ActivitySegment: Hashable {
    public var dateInterval: DateInterval
    public var totalActivityDuration: TimeInterval
    public var longestActivity: DateInterval?
    public var firstPickup: Date?
    public var totalPickupsWithoutApplicationActivity: Int
}

public struct Application: Equatable, Hashable {
    public let bundleIdentifier: String?
    public let token: ApplicationToken?
    public let localizedDisplayName: String?
}
```

Plus `CategoryActivity`, `WebDomainActivity`, `Device`, `User`, and a `DeviceActivityFilter`
that segments `.hourly` / `.daily` and filters by application, category or web domain.

### What this overturns

`01-FEASIBILITY.md` section 3 — *"Screen Time data cannot leave the report extension"* —
was the defining constraint of this project. It is the reason for the two-plane
architecture (D2), the threshold ladder (D3), the provenance chips, and the two-tier
statistics contract in `02-PRODUCT.md` §6.

On **iOS 26.4 and later, that constraint is gone.** Per-app duration, pickups,
notifications, category and web-domain totals, and app display names are all readable from
ordinary app code.

Three other consequences, stated plainly because they are corrections of things this repo
asserts:

1. `brand.json` → `anti_slop.forbidden_patterns` contains *"pickups and notifications do
   not exist outside the report extension"*. **That is now false** and has been rewritten.
2. Earlier in this project I removed `totalPickupsWithoutApplicationActivity` from the
   report extension because I could not verify it existed. It does exist, exactly under
   that name. Removing it rather than guessing was the right call, and it is now confirmed
   rather than assumed.
3. `Application.localizedDisplayName` and `bundleIdentifier` mean app names are no longer
   opaque. Stats can say "Instagram" instead of rendering a token.

### What it does **not** change

- **The blocker is untouched.** This is gated on authorization (§2), which is gated on the
  Family Controls entitlement, which needs the $99 membership. Nothing here makes the app
  run today.
- **Deployment target.** We build for iOS 26.0. This API is 26.4. Every use must be
  `@available`-gated, and the threshold ladder stays as the floor for 26.0–26.3 — it is
  not dead code, it is the fallback.
- **The ladder is still needed anyway.** `activityData` is an async read; the monitor
  extension still needs a *threshold* to be woken by. Measurement and triggering are
  different jobs.

**UNVERIFIED:** that it returns data from the app process at all; what `.live` costs in
battery versus `.cached`; how stale `.cached` is; whether it works in a
`DeviceActivityMonitor` extension.

---

## 2. A second authorization tier

**DECLARED** — `FamilyControls`, iOS 26.4:

```swift
public enum AuthorizationStatus: Int, Codable, CustomStringConvertible {
    case notDetermined
    case denied
    case approved
    @available(iOS 26.4, *)
    case approvedWithDataAccess
}
```

**INFERRED:** `approvedWithDataAccess` is the gate on §1, and corresponds to the new
"Family Controls App and Website Usage" capability. A developer-forum post from March 2026
([thread 820283](https://developer.apple.com/forums/thread/820283)) reports that adding
that capability changes the prompt to all-or-nothing — the user cannot grant shielding
without also granting data access. No Apple reply on that thread.

**Handled in code.** `MushAuthorizationStatus` gained the case plus two accessors,
`canShield` and `canReadUsage`, and every site that compared `== .approved` now asks
`canShield`. Without that, a user who granted the *higher* tier would have been told they
had not granted permission.

---

## 3. A shield can open our app

**DECLARED** — `ManagedSettings`, iOS 26.5:

```swift
public enum ShieldActionResponse: Int {
    case none
    case close
    case `defer`
    @available(iOS 26.5, *)
    case openParentalControlsApp
}
```

`01-FEASIBILITY.md` **L2** says a shield cannot open our app, quoting Apple DTS —
*"no supported way"* (FB15079668). That limitation drove the whole intervention design:
rich interventions had to be reached through a Shortcuts automation or a notification,
never from the shield.

Worth noting how recent this is: the developer of **one sec** was still asking for exactly
this API in March 2026 ([thread 820790](https://developer.apple.com/forums/thread/820790),
no reply, five feedback IDs listed). Search engines still say it does not exist. The
shipped interface says otherwise.

**UNVERIFIED, and it matters:** the name says *parental controls app*. Under `.individual`
authorization the app holding the authorization is the parental controls app — so this
most likely opens **us**. It could also mean Settings › Screen Time. Until it runs on a
device, the docs say "appears to" and the UI promises nothing.

---

## 4. The shield's secondary button is now a submenu

**DECLARED** — `ManagedSettings`, iOS 26.4:

```swift
public enum ShieldAction: Int {
    case primaryButtonPressed
    case secondaryButtonPressed
    @available(iOS 26.4, *) case firstSecondarySubmenuItemPressed
    @available(iOS 26.4, *) case secondSecondarySubmenuItemPressed
    @available(iOS 26.4, *) case thirdSecondarySubmenuItemPressed
}
```

Up to three items behind the secondary button. That is a real intervention surface: today
`Strictness` has one escape hatch, and this allows three with different costs — five
minutes at −2, a scheduled window, "not today". Not built yet.

Handled defensively now: the handler closes on anything it does not recognise, because the
one thing that must never happen by accident is granting access.

---

## 5. Token rotation and stale stores got official answers

**DECLARED** — `ManagedSettings`, iOS 26.x:

```swift
public static func refresh(_ tokens: inout [ApplicationToken]) throws
public static func refresh(_ tokens: inout [ActivityCategoryToken]) throws
public static func refresh(_ tokens: inout [WebDomainToken]) throws

public struct TokenExpiryMessage: NotificationCenter.AsyncMessage { ... }
public static var tokensDidExpire: BaseMessageIdentifier<TokenExpiryMessage> { get }

public func deleteStore()
public static func deleteStores(_ storeNames: Set<ManagedSettingsStore.Name>)
public static var stores: Set<ManagedSettingsStore.Name> { get }
```

- `refresh` + `tokensDidExpire` address **FB14082790**, the token rotation that forced our
  remapping design. There is now both a call and a notification.
- `deleteStore` / `deleteStores` / `stores` address **FB14237883**, the stale shield UI.
  `MaintenanceAction.reapplyShields` currently has to fake store enumeration; it can stop.

---

## 6. `FamilyActivityData.installedApplications`

**DECLARED** — `FamilyControls`:

```swift
public class FamilyActivityData {
    public var installedApplications: [ManagedSettings.Application] { get }
}
```

A list of installed apps, each with a bundle identifier and a display name.

**INFERRED:** this makes it possible to suggest apps to block rather than sending the user
into `FamilyActivityPicker` cold.

**UNVERIFIED:** what authorization it needs, and whether it is filtered.

---

## 7. What changes in the plan

| Doc | Change |
|---|---|
| `01-FEASIBILITY.md` §3 | Amended: true below 26.4, false from 26.4 |
| `01-FEASIBILITY.md` L2 | Amended: a response case now exists |
| `01-FEASIBILITY.md` capability table | "display-only" is wrong from 26.4 |
| `02-PRODUCT.md` §6 | The two-tier contract becomes version-dependent |
| `08-DECISIONS.md` | **D18** records how we adopt this without breaking 26.0 |
| `brand.json` | The pickups/notifications anti-slop rule was factually wrong |

### New open questions

- **Q6.** Does `activityData` return data outside a report extension in practice?
- **Q7.** `.live` vs `.cached` — latency, staleness, battery.
- **Q8.** Does `openParentalControlsApp` open *our* app, or Settings?
- **Q9.** Can a user reach plain `.approved`, or is it all-or-nothing once the usage
  capability is added? If all-or-nothing, adding it costs us users who would have accepted
  shielding alone.
