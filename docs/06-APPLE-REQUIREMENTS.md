# 06 · Apple tooling, signing, and what only you can do

Current situation: **Windows 11, no Mac, free Apple ID.** This file states exactly what
that permits, what it forbids, and the precise steps to unblock each thing.

---

## 1. What Claude Code can do from Windows, with no Apple account

Everything except compiling and installing:

- the complete Swift/SwiftUI source for the app and all five extensions
- the `XcodeGen` project spec, entitlement plists, Info.plists, build settings
- the brain-health engine and its unit tests
- the mock Screen Time provider and all synthetic data
- the Safari web-extension JS/JSON rules
- CI that **compiles the app and boots it in an iOS 26 Simulator**, then uploads
  screenshots — this needs **no Apple account and no code signing at all**, because
  Simulator builds are not signed

That last point matters: you can watch this app run, from Windows, for free.

---

## 2. What is impossible without a paid membership — $99/year

| Blocked thing | Why |
|---|---|
| Running on your iPhone with any Screen Time feature | `com.apple.developer.family-controls` is **not available to a free Personal Team** |
| Registering your iPhone 16 Pro UDID | Requires a Developer Program team |
| Any signed device build | A free Personal Team profile cannot carry the entitlement |
| Answering feasibility questions Q1–Q4 in `01` | They can only be tested on hardware |

There is no workaround. Not a technical limit we can engineer around — an account-tier
restriction Apple enforces at profile generation.

**A free Apple ID does not get you a degraded version of this app. It gets you an app
whose every core call fails at launch.**

---

## 3. If you enrol — the exact sequence

Everything here is doable **from Windows in a browser**, except step 6.

1. Enrol at `developer.apple.com/programs` ($99/yr). Individual is fine.
2. **Get your iPhone UDID.** Connect it, open iTunes/Devices & Drivers, or run
   `idevice_id -l` from libimobiledevice for Windows. Add it under
   *Certificates, IDs & Profiles → Devices*.
3. **Generate a signing key and CSR on Windows with OpenSSL** — no Mac keychain needed:
   ```sh
   openssl genrsa -out mush.key 2048
   openssl req -new -key mush.key -out mush.csr -subj "/emailAddress=YOU/CN=Mush/C=EC"
   ```
   Upload `mush.csr` to *Certificates → + → Apple Development*. Download `.cer`, then:
   ```sh
   openssl x509 -in development.cer -inform DER -out dev.pem -outform PEM
   openssl pkcs12 -export -inkey mush.key -in dev.pem -out mush.p12
   ```
4. **Register 6 App IDs** (app + 5 extensions) and enable **Family Controls** and **App
   Groups** on each. The app extension IDs must be children of the app ID.
5. **Create the App Group** `group.<PREFIX>.mush` and one **Development provisioning
   profile per App ID**, each including your device.
6. **Install the build.** Base64 the `.p12` and the six profiles into GitHub secrets; CI
   archives and exports a signed `.ipa`; then from Windows:
   ```sh
   ideviceinstaller -i Mush.ipa
   ```
   `libimobiledevice` runs on Windows, so this step needs no Mac either.

Realistic first-install time once enrolled: **60–90 minutes**, most of it portal clicking.

> Apple Developer Program enrolment approval itself can take 24–48 hours, occasionally
> longer for individuals. Budget for that before planning a build session.

---

## 4. Distribution entitlement — later, not now

For TestFlight or the App Store you additionally need **Family Controls (Distribution)**,
requested per bundle ID at `developer.apple.com/contact/request/family-controls-distribution`,
with a written justification of the parental-control / digital-wellbeing use case, filed
separately for the app and for each Screen Time extension. Approval takes days to weeks.

Explicitly out of scope for now — the objective is a development build on your device.

---

## 5. Why GitHub Actions rather than a cloud Mac

- `macos-26` runners are **generally available**, run on Apple Silicon, and ship Xcode 26
  with the iOS 26 SDK
- free minutes cover our build volume; a rented Mac is $10–30/month for the same result
- the build is reproducible and scripted, which matters more than interactive Xcode when
  the author of the code is not the person at the keyboard

The tradeoff is real and worth stating: **no interactive debugger and no Instruments.**
For a project this dependent on on-device extension behaviour, that will hurt during
Phase 2+. If we hit a wall diagnosing extension callbacks, renting a Mac for a few days
is the correct escalation, not a failure of the plan.
