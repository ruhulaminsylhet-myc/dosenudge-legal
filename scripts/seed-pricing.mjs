#!/usr/bin/env node
// Writes the initial config/pricing document so the admin panel's Pricing page
// opens with real stored values instead of the in-code fallbacks.
//
// Usage:
//   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccountKey.json
//   node scripts/seed-pricing.mjs            # GBP defaults (UK launch)
//   node scripts/seed-pricing.mjs BDT        # Bangladesh defaults
//
// Re-running overwrites the document, so edit rates in the admin panel rather
// than here once you are live.

import { applicationDefault, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

const PRESETS = {
  GBP: {
    currency: "GBP",
    baseFare: 2.5,
    perKm: 1.2,
    perMin: 0.15,
    minimumFare: 4.0,
    commissionPct: 15,
    searchRadiusKm: 8,
    maxDriversNotified: 10,
    requestTimeoutSec: 120,
    cancellationFee: 3.0,
    freeCancellationSec: 120,
    maxRouteFactor: 2.5,
  },
  BDT: {
    currency: "BDT",
    baseFare: 50,
    perKm: 25,
    perMin: 2,
    minimumFare: 80,
    commissionPct: 15,
    searchRadiusKm: 5,
    maxDriversNotified: 15,
    requestTimeoutSec: 120,
    cancellationFee: 60,
    freeCancellationSec: 120,
    maxRouteFactor: 2.5,
  },
};

const currency = (process.argv[2] ?? "GBP").toUpperCase();
const preset = PRESETS[currency];
if (!preset) {
  console.error(
    `Unknown currency "${currency}". Available presets: ${Object.keys(PRESETS).join(", ")}`
  );
  process.exit(1);
}

initializeApp({ credential: applicationDefault() });
await getFirestore().doc("config/pricing").set(preset);

console.log(`✔ config/pricing seeded with ${currency} defaults:`);
console.table(preset);
console.log("Adjust these any time from the admin panel → Pricing.");
