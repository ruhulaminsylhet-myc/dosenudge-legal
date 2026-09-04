#!/usr/bin/env node
// Fills a running emulator with a demo admin, riders, drivers and rides so the
// admin panel can be run and clicked through without any Firebase project.
//
// Terminal 1:  firebase emulators:start --only auth,firestore --project demo-taxi
// Terminal 2:  node scripts/seed-emulator.mjs
// Terminal 3:  cd apps/admin_panel && NEXT_PUBLIC_USE_EMULATOR=true npm run dev
//
// Then sign in at http://localhost:3000 with admin@demo.test / demo1234
//
// Refuses to run against a real project: it only ever talks to the emulator.

import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore, GeoPoint } from "firebase-admin/firestore";

const PROJECT_ID = process.env.GCLOUD_PROJECT ?? "demo-taxi";
process.env.FIRESTORE_EMULATOR_HOST ??= "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= "127.0.0.1:9099";

if (!process.env.FIRESTORE_EMULATOR_HOST.startsWith("127.0.0.1")) {
  console.error("Refusing to seed: FIRESTORE_EMULATOR_HOST is not local.");
  process.exit(1);
}

initializeApp({ projectId: PROJECT_ID });
const auth = getAuth();
const db = getFirestore();

const PASSWORD = "demo1234";

async function upsertUser(uid, email, displayName, claims) {
  try {
    await auth.createUser({ uid, email, password: PASSWORD, displayName });
  } catch (err) {
    if (err.code !== "auth/uid-already-exists") throw err;
  }
  await auth.setCustomUserClaims(uid, claims);
}

const PEOPLE = [
  { uid: "admin1", email: "admin@demo.test", name: "Ruhul (Admin)", role: "admin", claims: { admin: true } },
  { uid: "rider1", email: "rider1@demo.test", name: "Aisha Rahman", role: "rider", claims: { role: "rider" } },
  { uid: "rider2", email: "rider2@demo.test", name: "Tom Blake", role: "rider", claims: { role: "rider" } },
  { uid: "driver1", email: "driver1@demo.test", name: "Karim Uddin", role: "driver", claims: { role: "driver" } },
  { uid: "driver2", email: "driver2@demo.test", name: "Sofia Marino", role: "driver", claims: { role: "driver" } },
  { uid: "driver3", email: "driver3@demo.test", name: "Jamal Hossain", role: "driver", claims: { role: "driver" } },
];

const DRIVERS = [
  {
    uid: "driver1",
    approvalStatus: "approved",
    isOnline: true,
    vehicle: { make: "Toyota", model: "Prius", color: "Silver", plate: "MK21 TXA", type: "standard" },
    rating: 4.8,
    ratingCount: 42,
    totalRides: 47,
    totalEarnings: 612.35,
    documents: {
      licence: "https://example.com/demo/licence1.jpg",
      insurance: "https://example.com/demo/insurance1.pdf",
      vehiclePhoto: "https://example.com/demo/car1.jpg",
    },
  },
  {
    uid: "driver2",
    approvalStatus: "approved",
    isOnline: false,
    vehicle: { make: "Skoda", model: "Octavia", color: "Black", plate: "LN70 QRS", type: "executive" },
    rating: 4.6,
    ratingCount: 18,
    totalRides: 20,
    totalEarnings: 289.1,
    documents: {
      licence: "https://example.com/demo/licence2.jpg",
      insurance: "https://example.com/demo/insurance2.pdf",
      vehiclePhoto: "https://example.com/demo/car2.jpg",
    },
  },
  {
    uid: "driver3",
    approvalStatus: "pending",
    isOnline: false,
    vehicle: { make: "Ford", model: "Galaxy", color: "Blue", plate: "BX19 KLM", type: "xl" },
    rating: 0,
    ratingCount: 0,
    totalRides: 0,
    totalEarnings: 0,
    documents: { licence: "https://example.com/demo/licence3.jpg" },
  },
];

const MK = { lat: 52.0406, lng: -0.7594 };

const RIDES = [
  {
    id: "ride_active",
    riderId: "rider1",
    riderName: "Aisha Rahman",
    driverId: "driver1",
    status: "in_progress",
    pickup: { ...MK, address: "Milton Keynes Central Station" },
    dropoff: { lat: 52.0, lng: -0.73, address: "Bletchley Park" },
    estimatedDistanceKm: 4.2,
    minutesAgo: 6,
  },
  {
    id: "ride_waiting",
    riderId: "rider2",
    riderName: "Tom Blake",
    driverId: null,
    status: "requested",
    pickup: { lat: 52.05, lng: -0.77, address: "Campbell Park" },
    dropoff: { lat: 52.02, lng: -0.79, address: "Furzton Lake" },
    estimatedDistanceKm: 5.1,
    minutesAgo: 1,
  },
  {
    id: "ride_done1",
    riderId: "rider1",
    riderName: "Aisha Rahman",
    driverId: "driver1",
    status: "completed",
    pickup: { lat: 52.03, lng: -0.75, address: "Xscape, Milton Keynes" },
    dropoff: { lat: 52.06, lng: -0.72, address: "Newport Pagnell" },
    estimatedDistanceKm: 7.8,
    minutesAgo: 180,
    rating: 5,
  },
  {
    id: "ride_done2",
    riderId: "rider2",
    riderName: "Tom Blake",
    driverId: "driver2",
    status: "completed",
    pickup: { lat: 52.01, lng: -0.78, address: "Westcroft District Centre" },
    dropoff: { ...MK, address: "Milton Keynes Central Station" },
    estimatedDistanceKm: 6.3,
    minutesAgo: 400,
    rating: 4,
  },
  {
    id: "ride_cancelled",
    riderId: "rider1",
    riderName: "Aisha Rahman",
    driverId: null,
    status: "cancelled",
    pickup: { lat: 52.04, lng: -0.76, address: "Theatre District" },
    dropoff: { lat: 52.07, lng: -0.71, address: "Willen Lake" },
    estimatedDistanceKm: 3.4,
    minutesAgo: 60,
    cancelledBy: "rider",
  },
];

const PRICING = {
  currency: "GBP",
  baseFare: 2.5,
  perKm: 1.2,
  perMin: 0.15,
  minimumFare: 4.0,
  commissionPct: 15,
  searchRadiusKm: 8,
  maxDriversNotified: 10,
  requestTimeoutSec: 120,
};

const round2 = (n) => Math.round(n * 100) / 100;

function fareFor(distanceKm) {
  const durationMin = Math.max(1, Math.round((distanceKm / 30) * 60));
  const total = round2(
    Math.max(
      PRICING.baseFare + distanceKm * PRICING.perKm + durationMin * PRICING.perMin,
      PRICING.minimumFare
    )
  );
  const commission = round2(total * (PRICING.commissionPct / 100));
  return {
    currency: PRICING.currency,
    base: PRICING.baseFare,
    distanceCharge: round2(distanceKm * PRICING.perKm),
    timeCharge: round2(durationMin * PRICING.perMin),
    total,
    commission,
    driverPayout: round2(total - commission),
  };
}

const minutesAgo = (m) => new Date(Date.now() - m * 60_000);

// ---------------------------------------------------------------------------

PEOPLE.forEach((p, i) => {
  p.phone = `0770090${String(1000 + i).slice(-4)}`;
});

for (const p of PEOPLE) {
  await upsertUser(p.uid, p.email, p.name, p.claims);
  await db.doc(`users/${p.uid}`).set({
    role: p.role,
    status: "active",
    name: p.name,
    email: p.email,
    phone: p.phone,
    createdAt: FieldValue.serverTimestamp(),
  });
}

for (const d of DRIVERS) {
  const person = PEOPLE.find((p) => p.uid === d.uid);
  await db.doc(`drivers/${d.uid}`).set({
    name: person.name,
    phone: person.phone,
    approvalStatus: d.approvalStatus,
    isOnline: d.isOnline,
    vehicle: d.vehicle,
    location: new GeoPoint(MK.lat, MK.lng),
    geohash: "gcqx",
    rating: d.rating,
    ratingCount: d.ratingCount,
    totalRides: d.totalRides,
    totalEarnings: d.totalEarnings,
    documents: d.documents,
    updatedAt: FieldValue.serverTimestamp(),
  });
}

for (const r of RIDES) {
  const fare = fareFor(r.estimatedDistanceKm);
  const completed = r.status === "completed";
  await db.doc(`rides/${r.id}`).set({
    riderId: r.riderId,
    riderName: r.riderName,
    driverId: r.driverId,
    status: r.status,
    pickup: r.pickup,
    dropoff: r.dropoff,
    estimatedDistanceKm: r.estimatedDistanceKm,
    estimatedDurationMin: Math.max(1, Math.round((r.estimatedDistanceKm / 30) * 60)),
    fareEstimate: fare,
    finalFare: completed ? fare : null,
    offeredTo: r.driverId ? [r.driverId] : ["driver1"],
    requestedAt: minutesAgo(r.minutesAgo),
    ...(r.rating ? { rating: r.rating } : {}),
    ...(r.cancelledBy ? { cancelledBy: r.cancelledBy } : {}),
  });

  if (completed) {
    await db.collection("earnings").doc(`earn_${r.id}`).set({
      driverId: r.driverId,
      rideId: r.id,
      currency: fare.currency,
      grossFare: fare.total,
      commission: fare.commission,
      netPayout: fare.driverPayout,
      createdAt: minutesAgo(r.minutesAgo - 5),
    });
  }
}

await db.doc("config/pricing").set(PRICING);

console.log(`✔ Seeded emulator project "${PROJECT_ID}":
  ${PEOPLE.length} users (1 admin, 2 riders, 3 drivers)
  ${DRIVERS.length} driver profiles (2 approved, 1 pending approval)
  ${RIDES.length} rides (1 in progress, 1 waiting, 2 completed, 1 cancelled)
  config/pricing in ${PRICING.currency}

Sign in to the admin panel with:  admin@demo.test / ${PASSWORD}
`);
