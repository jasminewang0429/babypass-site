# BabyPass

A free iOS marketplace for parents to buy and sell secondhand baby and kids' gear locally.
Strollers, car seats, clothes, toys, books, nursery — no fees, no shipping, local pickup only.

**Status:** Live on the App Store · [App Store listing](https://apps.apple.com/app/id6765940379)

## Tech stack

- **iOS:** SwiftUI, single-target app (iOS 16+)
- **Backend:** Firebase Auth (email/password), Firestore, Storage
- **Web (storefront share):** Firebase Hosting + Firebase Web SDK v10 (vanilla JS, no build step)
- **Map:** MapKit
- No third-party UI libraries, no SwiftPM dependencies beyond Firebase, no test target

## Repo layout

```
BabyPass/
├── BabyPass.xcodeproj          ← Xcode project
├── BabyPass/                   ← SwiftUI source
│   ├── BabyPassApp.swift       ← app entry
│   ├── ContentView.swift
│   ├── MainTabView.swift
│   ├── AuthService.swift       ← Firebase Auth wrapper
│   ├── DataService.swift       ← Firestore + Storage wrapper
│   ├── Models.swift            ← Codable structs
│   └── ...
├── public/                     ← Firebase Hosting site (storefront share)
├── firestore.rules             ← deployed Firestore security rules
├── firebase.json
├── AppStore-Submission-Guide.md
├── Storefront-Share.md         ← feature doc for the share button + web storefront
└── README.md                   ← you are here
```

## Build & run (iOS app)

Requires Xcode 15+ on macOS, plus the Apple Developer ID configured for this project.

```bash
open BabyPass.xcodeproj
```

Then in Xcode:
1. Select the `BabyPass` scheme + iPhone 15 Pro Max simulator (the target device for App Store screenshots)
2. ⌘R to build & run

The app talks to live Firebase — there is no staging environment. `GoogleService-Info.plist` is required and gitignored; keep your own copy at `BabyPass/GoogleService-Info.plist`.

## Deploy (web storefront)

The storefront page that the in-app share button links to lives at `public/` and is served from Firebase Hosting at `https://babypass-49b45.web.app`.

```bash
firebase deploy --only hosting --project babypass-49b45
```

Deploys are atomic (~20 sec) and instantly rollback-able from Firebase Console → Hosting → Release history.

## Ship to App Store

See [`AppStore-Submission-Guide.md`](AppStore-Submission-Guide.md) for the full checklist.

Short version: bump Version + Build in Xcode → Product → Archive → upload via Organizer → fill release notes in App Store Connect → Submit for Review.

## Versioning

Marketing version follows a loose semver:
- Major (`1.x → 2.x`): big redesigns or breaking changes
- Minor (`1.4 → 1.5`): new user-visible features
- Patch (`1.4 → 1.4.1`): bug fixes

Build number must increment for every App Store Connect upload, regardless of version.

## Docs

- [`Storefront-Share.md`](Storefront-Share.md) — share-your-listings feature (iOS toolbar button + public web storefront)
- [`AppStore-Submission-Guide.md`](AppStore-Submission-Guide.md) — submission workflow & metadata
- [`firestore.rules`](firestore.rules) — header comments document the security model and why certain checks were intentionally omitted

## Privacy & legal

- [`privacy-policy.html`](privacy-policy.html)
- [`terms-of-use.html`](terms-of-use.html)
- [`support.html`](support.html)
