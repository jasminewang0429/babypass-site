// One-off backfill for listings.locationText.
//
// Existing listings only stored latitude/longitude; the web storefront
// (public/s.html) reverse-geocoded those coords via bigdatacloud's free
// API, which returned the nearest metro city (e.g. "Boston, MA") instead
// of the actual town ("Wayland, MA"). New listings now persist the seller's
// chosen location text directly. This script backfills the field on docs
// posted before that change, using OpenStreetMap Nominatim — more accurate
// for US small towns and free with no API key.
//
// Usage:
//   1. Authenticate once with Application Default Credentials:
//        gcloud auth application-default login
//      OR set GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
//      (Firebase Console → Project Settings → Service Accounts → Generate)
//
//   2. From BabyPass/functions/:
//        node scripts/backfill-location-text.js              # dry run
//        node scripts/backfill-location-text.js --apply      # actually write
//
// Nominatim usage policy: <= 1 request per second, identify the app via
// User-Agent. Both honored below. Do not run this script in a tight loop.

const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

const PROJECT_ID = "babypass-49b45";
const USER_AGENT = "BabyPass-Backfill/1.0";
const NOMINATIM_DELAY_MS = 1100;

const APPLY = process.argv.includes("--apply");

initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Nominatim returns an `address` object with many possible locality fields.
// For US: small towns surface as `town`, cities as `city`, very small places
// as `village`/`hamlet`. State abbreviation lives in `ISO3166-2-lvl4` as
// "US-MA"; we split on the dash.
function deriveLocationText(address) {
  if (!address) return null;
  const locality =
    address.town ||
    address.city ||
    address.village ||
    address.hamlet ||
    address.municipality ||
    address.suburb ||
    null;
  if (!locality) return null;
  const iso = address["ISO3166-2-lvl4"] || "";
  const stateAbbr = iso.startsWith("US-") ? iso.slice(3) : (address.state || "");
  return stateAbbr ? `${locality}, ${stateAbbr}` : locality;
}

async function reverseGeocode(lat, lng) {
  const url = `https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lng}&format=jsonv2&zoom=10&addressdetails=1`;
  const res = await fetch(url, { headers: { "User-Agent": USER_AGENT } });
  if (!res.ok) throw new Error(`Nominatim HTTP ${res.status}`);
  const data = await res.json();
  return deriveLocationText(data.address);
}

async function main() {
  console.log(`Mode: ${APPLY ? "APPLY (will write)" : "DRY RUN (no writes)"}`);
  console.log(`Project: ${PROJECT_ID}\n`);

  const snap = await db.collection("listings").get();
  const totals = { scanned: 0, alreadyHas: 0, noCoords: 0, geocodeFailed: 0, wouldWrite: 0, wrote: 0 };

  for (const doc of snap.docs) {
    totals.scanned += 1;
    const data = doc.data();
    const id = doc.id;

    if (typeof data.locationText === "string" && data.locationText.trim() !== "") {
      totals.alreadyHas += 1;
      continue;
    }
    if (typeof data.latitude !== "number" || typeof data.longitude !== "number") {
      totals.noCoords += 1;
      console.log(`[skip] ${id} — missing coords`);
      continue;
    }

    let derived;
    try {
      derived = await reverseGeocode(data.latitude, data.longitude);
    } catch (err) {
      totals.geocodeFailed += 1;
      console.log(`[fail] ${id} — geocoder error: ${err.message}`);
      await sleep(NOMINATIM_DELAY_MS);
      continue;
    }

    if (!derived) {
      totals.geocodeFailed += 1;
      console.log(`[fail] ${id} — no locality at ${data.latitude},${data.longitude}`);
      await sleep(NOMINATIM_DELAY_MS);
      continue;
    }

    const title = (data.title || "").slice(0, 40);
    console.log(`[ok]   ${id} (${title}) → "${derived}"`);

    if (APPLY) {
      await doc.ref.update({ locationText: derived, locationTextBackfilledAt: FieldValue.serverTimestamp() });
      totals.wrote += 1;
    } else {
      totals.wouldWrite += 1;
    }

    await sleep(NOMINATIM_DELAY_MS);
  }

  console.log("\n--- summary ---");
  console.log(`scanned:        ${totals.scanned}`);
  console.log(`already has:    ${totals.alreadyHas}`);
  console.log(`missing coords: ${totals.noCoords}`);
  console.log(`geocode failed: ${totals.geocodeFailed}`);
  console.log(APPLY ? `wrote:          ${totals.wrote}` : `would write:    ${totals.wouldWrite}`);
  if (!APPLY) console.log("\nRe-run with --apply to commit these changes.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
