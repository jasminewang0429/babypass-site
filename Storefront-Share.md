# Storefront Share — feature notes

A "Share my listings" feature: a toolbar button on the **My Listings** page that produces a public web URL anyone can open in a browser. The page shows the seller's active listings (photo, title, price, condition, city/state) plus a "Join BabyPass" CTA.

## Live URLs

- Landing: https://babypass-49b45.web.app/
- Storefront pattern: `https://babypass-49b45.web.app/s/{sellerUid}`
- Your storefront: https://babypass-49b45.web.app/s/br8exlRJOhMzdlKK5iuTZDT2D622

The storefront page reads listings directly from Firestore client-side (no backend). `firestore.rules` already allows public reads on `listings` (`allow read: if true`).

## Files touched

| File | What it does |
|---|---|
| `public/index.html` | Bare landing page at `/` |
| `public/s.html` | Storefront SPA. Reads `?sellerUid` from path, queries Firestore, renders cards, reverse-geocodes lat/lng → "City, ST" via BigDataCloud free API |
| `public/style.css` | Shared styles, BabyPass pink theme |
| `public/404.html` | Fallback |
| `firebase.json` | Added `hosting` section with `/s/**` → `/s.html` rewrite |
| `firestore.indexes.json` | Reverted to empty — storefront uses a single-field query + client-side filter, so no composite index needed |
| `BabyPass/MyListingsView.swift` | Added `import FirebaseAuth` + toolbar `ShareLink` |

## Manual test checklist

Run through these after any change to the storefront or share button. **No automated tests exist** — manual is the bar.

### Web (open in any browser)

- [ ] `https://babypass-49b45.web.app/` → landing page renders, "Install BabyPass" button visible
- [ ] `https://babypass-49b45.web.app/s/{your-uid}` → your active listings render with photos, prices, "📍 City, ST" line, condition + category emoji
- [ ] `https://babypass-49b45.web.app/s/notarealuid` → empty state ("This seller doesn't have anything for sale right now.")
- [ ] DevTools console (Cmd+Opt+J in Chrome, Cmd+Opt+C in Safari) shows **no red errors**
- [ ] "Join BabyPass" banner appears below the listings grid
- [ ] **Open Graph preview**: paste the storefront URL into iMessage to yourself → the link should expand to a preview card with title + image (first listing photo). May take 30–60s the first time as Apple caches.

### iOS app (Xcode → iPhone 15 Pro Max simulator)

- [ ] Sign in, navigate to **Me → My Listings**
- [ ] **square-and-arrow-up** icon visible in the top-right toolbar
- [ ] Tap it → iOS share sheet appears with URL `https://babypass-49b45.web.app/s/{your-uid}` and message "Check out what I'm selling on BabyPass!"
- [ ] Cancel out, open the URL in mobile Safari → confirm same content as desktop

### Edge cases worth re-running occasionally

- [ ] User with zero active listings → empty state, share button still works
- [ ] Listing with `photoURLs: []` → card shows category-emoji placeholder
- [ ] BigDataCloud rate-limited or down → cards fall back to "📍 Local pickup" silently (no error)

## TODO

- [x] **Real App Store URL wired in** (2026-05-26). App Store ID: `6765940379` → `https://apps.apple.com/app/id6765940379` in both `public/s.html` and `public/index.html`.
- [ ] **Privacy hardening for coordinates** *(not urgent)*: the storefront fetches raw `latitude`/`longitude` from each listing doc, then reverse-geocodes client-side to city/state. The exact coordinates are still readable in DevTools → Network → Firestore response. If that becomes a concern, the fix is to denormalize a `cityName` field at post-time (in `SellView.swift` / `DataService.postListing`) and stop sending lat/lng to web clients. Requires changes to:
  - `Models.swift` — add `cityName: String?` to `Listing`
  - `DataService.swift` — `postListing` reverse-geocodes on iOS via `CLGeocoder` and writes `cityName`
  - `firestore.rules` — optionally restrict raw `latitude`/`longitude` reads (would need denormalized rule logic)
  - `s.html` — switch to reading `cityName` directly, drop the BigDataCloud call

## Redeploy

```bash
cd BabyPass
firebase deploy --only hosting --project babypass-49b45
```

Hosting deploys are atomic and instantly reversible from the Firebase Console (**Hosting → Release history → Roll back**) if anything goes wrong.

## Local dev / preview

```bash
cd BabyPass
firebase emulators:start --only hosting --project babypass-49b45
# then visit http://localhost:5002/s/{your-uid}
```

The local emulator serves the static files but the page still hits **live Firestore** for listing data. Browsers cache `s.html` aggressively — hard-refresh with `Cmd+Shift+R` (Chrome) or `Cmd+Opt+R` (Safari) after editing.

## Why this architecture (vs. alternatives we considered)

- **Plain text share via `ShareLink`** — recipient has to install + manually search for the seller. Weakest conversion path.
- **Generated image share** — eye-catching but no clickable destination.
- **Universal Links / deep linking back into the app** — requires `apple-app-site-association`, Associated Domains entitlement, and a live App Store URL. Deferred until after launch.
- **Public web page (chosen)** — recipient can browse instantly without installing. Doubles as a marketing surface (paste into Instagram bio, neighborhood Facebook groups, etc.). No backend needed because Firestore listing reads are already public.

## Original plan reference

Full design rationale is at `~/.claude/plans/current-app-is-not-velvet-nygaard.md`.
