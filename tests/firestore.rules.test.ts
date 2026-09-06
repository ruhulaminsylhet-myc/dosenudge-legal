import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc, updateDoc } from "firebase/firestore";
import { afterAll, beforeAll, beforeEach, describe, test } from "vitest";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");

const RIDER = "rider1";
const OTHER_RIDER = "rider2";
const NEAR_DRIVER = "driver1"; // offered this ride
const FAR_DRIVER = "driver2"; // not offered
const PENDING_DRIVER = "driver3"; // application not yet reviewed
const ADMIN = "admin1";

let env: RulesTestEnvironment;

/** Signed-in contexts carry the same custom claims the functions set. */
const rider = (uid = RIDER) => env.authenticatedContext(uid, { role: "rider" }).firestore();
const driver = (uid = NEAR_DRIVER) => env.authenticatedContext(uid, { role: "driver" }).firestore();
const admin = () => env.authenticatedContext(ADMIN, { admin: true }).firestore();

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-taxi",
    firestore: {
      rules: readFileSync(join(ROOT, "firestore.rules"), "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });
});

afterAll(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  // Seed through an unrestricted context — this is fixture setup, not a test.
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "users", RIDER), {
      role: "rider",
      status: "active",
      name: "Rider One",
      phone: "07000000001",
      email: "rider1@example.com",
    });
    await setDoc(doc(db, "drivers", NEAR_DRIVER), {
      name: "Driver One",
      phone: "07000000002",
      approvalStatus: "approved",
      isOnline: true,
      vehicle: { make: "Toyota", model: "Prius", color: "Silver", plate: "AB12 CDE" },
      rating: 4.8,
      ratingCount: 10,
      totalRides: 10,
      totalEarnings: 250,
      stripeAccountId: "acct_demo",
      payoutsEnabled: true,
    });
    await setDoc(doc(db, "drivers", PENDING_DRIVER), {
      name: "Driver Three",
      phone: "07000000003",
      approvalStatus: "pending",
      isOnline: false,
      vehicle: { make: "Ford", model: "Focus", color: "Blue", plate: "XY34 ZZZ" },
      rating: 0,
      ratingCount: 0,
      totalRides: 0,
      totalEarnings: 0,
      expiryBlocked: true,
    });
    await setDoc(doc(db, "rides", "openRide"), {
      riderId: RIDER,
      riderName: "Rider One",
      driverId: null,
      status: "requested",
      pickup: { lat: 52.04, lng: -0.76, address: "Milton Keynes" },
      dropoff: { lat: 52.05, lng: -0.75, address: "Bletchley" },
      estimatedDistanceKm: 3,
      offeredTo: [NEAR_DRIVER],
    });
    await setDoc(doc(db, "earnings", "e1"), {
      driverId: NEAR_DRIVER,
      rideId: "openRide",
      netPayout: 10,
    });
  });
});

describe("drivers collection", () => {
  test("a driver can read their own profile", async () => {
    await assertSucceeds(getDoc(doc(driver(), "drivers", NEAR_DRIVER)));
  });

  test("a rider cannot read a driver profile (phone, live location)", async () => {
    await assertFails(getDoc(doc(rider(), "drivers", NEAR_DRIVER)));
  });

  test("another driver cannot read a driver profile", async () => {
    await assertFails(getDoc(doc(driver(FAR_DRIVER), "drivers", NEAR_DRIVER)));
  });

  test("an admin can read any driver profile", async () => {
    await assertSucceeds(getDoc(doc(admin(), "drivers", NEAR_DRIVER)));
  });

  test("a pending driver cannot approve themselves", async () => {
    await assertFails(
      updateDoc(doc(driver(PENDING_DRIVER), "drivers", PENDING_DRIVER), {
        approvalStatus: "approved",
      })
    );
  });

  test("a driver cannot inflate their own rating or earnings", async () => {
    await assertFails(updateDoc(doc(driver(), "drivers", NEAR_DRIVER), { rating: 5 }));
    await assertFails(
      updateDoc(doc(driver(), "drivers", NEAR_DRIVER), { totalEarnings: 99999 })
    );
  });

  test("a driver cannot enable their own Stripe payouts", async () => {
    await assertFails(
      updateDoc(doc(driver(), "drivers", NEAR_DRIVER), { payoutsEnabled: false })
    );
    await assertFails(
      updateDoc(doc(driver(), "drivers", NEAR_DRIVER), {
        stripeAccountId: "acct_attacker",
      })
    );
  });

  test("a driver cannot clear the expired-documents block", async () => {
    await assertFails(
      updateDoc(doc(driver(PENDING_DRIVER), "drivers", PENDING_DRIVER), {
        expiryBlocked: false,
      })
    );
  });

  test("a driver can upload a document with its expiry date", async () => {
    await assertSucceeds(
      updateDoc(doc(driver(), "drivers", NEAR_DRIVER), {
        "documents.insurance": {
          url: "https://example.com/insurance.pdf",
          expiresAt: "2030-01-01",
        },
      })
    );
  });

  test("a driver can update their own location and online flag", async () => {
    await assertSucceeds(
      updateDoc(doc(driver(), "drivers", NEAR_DRIVER), {
        isOnline: false,
        geohash: "gcqx",
      })
    );
  });
});

describe("open ride requests", () => {
  test("a driver the ride was offered to can read it", async () => {
    await assertSucceeds(getDoc(doc(driver(NEAR_DRIVER), "rides", "openRide")));
  });

  test("a driver the ride was NOT offered to cannot read it", async () => {
    await assertFails(getDoc(doc(driver(FAR_DRIVER), "rides", "openRide")));
  });

  test("an unrelated rider cannot read someone else's ride", async () => {
    await assertFails(getDoc(doc(rider(OTHER_RIDER), "rides", "openRide")));
  });

  test("the owning rider can read their own ride", async () => {
    await assertSucceeds(getDoc(doc(rider(), "rides", "openRide")));
  });

  test("an offered driver can claim the ride", async () => {
    await assertSucceeds(
      updateDoc(doc(driver(NEAR_DRIVER), "rides", "openRide"), {
        status: "accepted",
        driverId: NEAR_DRIVER,
      })
    );
  });

  test("a driver not offered the ride cannot claim it", async () => {
    await assertFails(
      updateDoc(doc(driver(FAR_DRIVER), "rides", "openRide"), {
        status: "accepted",
        driverId: FAR_DRIVER,
      })
    );
  });

  test("a driver cannot claim a ride on another driver's behalf", async () => {
    await assertFails(
      updateDoc(doc(driver(NEAR_DRIVER), "rides", "openRide"), {
        status: "accepted",
        driverId: FAR_DRIVER,
      })
    );
  });

  test("a rider cannot self-assign a driver", async () => {
    await assertFails(
      updateDoc(doc(rider(), "rides", "openRide"), {
        status: "accepted",
        driverId: NEAR_DRIVER,
      })
    );
  });
});

describe("ride status machine", () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), "rides", "openRide"), {
        status: "accepted",
        driverId: NEAR_DRIVER,
      });
    });
  });

  test("the assigned driver can advance accepted -> arrived", async () => {
    await assertSucceeds(
      updateDoc(doc(driver(NEAR_DRIVER), "rides", "openRide"), { status: "arrived" })
    );
  });

  test("the assigned driver cannot skip straight to completed", async () => {
    await assertFails(
      updateDoc(doc(driver(NEAR_DRIVER), "rides", "openRide"), { status: "completed" })
    );
  });

  test("an unrelated driver cannot advance the ride", async () => {
    await assertFails(
      updateDoc(doc(driver(FAR_DRIVER), "rides", "openRide"), { status: "arrived" })
    );
  });

  test("the rider can cancel before pickup", async () => {
    await assertSucceeds(
      updateDoc(doc(rider(), "rides", "openRide"), {
        status: "cancelled",
        cancelledBy: "rider",
      })
    );
  });

  test("the rider cannot blame the driver to dodge the cancellation fee", async () => {
    await assertFails(
      updateDoc(doc(rider(), "rides", "openRide"), {
        status: "cancelled",
        cancelledBy: "driver",
      })
    );
  });

  test("a driver cannot blame the rider to earn a cancellation fee", async () => {
    await assertFails(
      updateDoc(doc(driver(NEAR_DRIVER), "rides", "openRide"), {
        status: "cancelled",
        cancelledBy: "rider",
      })
    );
  });

  test("the rider cannot write their own cancellation charge", async () => {
    await assertFails(
      updateDoc(doc(rider(), "rides", "openRide"), {
        status: "cancelled",
        cancelledBy: "rider",
        cancellationCharge: { currency: "GBP", amount: 0, commission: 0, driverPayout: 0 },
      })
    );
  });

  test("the rider cannot mark the trip completed to dodge the fare", async () => {
    await assertFails(
      updateDoc(doc(rider(), "rides", "openRide"), { status: "completed" })
    );
  });

  test("the driver's app can report the trip getting longer", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), "rides", "openRide"), {
        status: "in_progress",
        meteredDistanceKm: 2,
      });
    });
    await assertSucceeds(
      updateDoc(doc(driver(NEAR_DRIVER), "rides", "openRide"), {
        meteredDistanceKm: 2.4,
      })
    );
  });

  test("the driver cannot wind the metered distance back down", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), "rides", "openRide"), {
        status: "in_progress",
        meteredDistanceKm: 5,
      });
    });
    await assertFails(
      updateDoc(doc(driver(NEAR_DRIVER), "rides", "openRide"), {
        meteredDistanceKm: 1,
      })
    );
  });

  test("a driver cannot meter someone else's trip", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), "rides", "openRide"), {
        status: "in_progress",
      });
    });
    await assertFails(
      updateDoc(doc(driver(FAR_DRIVER), "rides", "openRide"), {
        meteredDistanceKm: 99,
      })
    );
  });

  test("metering is rejected once the trip is over", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), "rides", "openRide"), {
        status: "completed",
      });
    });
    await assertFails(
      updateDoc(doc(driver(NEAR_DRIVER), "rides", "openRide"), {
        meteredDistanceKm: 99,
      })
    );
  });

  test("the driver cannot rewrite the fare while advancing status", async () => {
    await assertFails(
      updateDoc(doc(driver(NEAR_DRIVER), "rides", "openRide"), {
        status: "arrived",
        finalFare: { currency: "GBP", total: 999, commission: 0, driverPayout: 999 },
      })
    );
  });

  test("the driver cannot inflate the distance settlement prices from", async () => {
    await assertFails(
      updateDoc(doc(driver(NEAR_DRIVER), "rides", "openRide"), {
        status: "arrived",
        estimatedDistanceKm: 500,
      })
    );
  });

  test("the driver cannot pre-set the rating to block the rider's review", async () => {
    await assertFails(
      updateDoc(doc(driver(NEAR_DRIVER), "rides", "openRide"), {
        status: "arrived",
        rating: 5,
      })
    );
  });

  test("the rider cannot widen who the ride was offered to", async () => {
    await assertFails(
      updateDoc(doc(rider(), "rides", "openRide"), {
        status: "cancelled",
        cancelledBy: "rider",
        offeredTo: [FAR_DRIVER],
      })
    );
  });
});

describe("earnings ledger", () => {
  test("a driver can read their own entries", async () => {
    await assertSucceeds(getDoc(doc(driver(NEAR_DRIVER), "earnings", "e1")));
  });

  test("another driver cannot read them", async () => {
    await assertFails(getDoc(doc(driver(FAR_DRIVER), "earnings", "e1")));
  });

  test("no client can write the ledger", async () => {
    await assertFails(
      setDoc(doc(driver(NEAR_DRIVER), "earnings", "fake"), {
        driverId: NEAR_DRIVER,
        netPayout: 1000,
      })
    );
    await assertFails(
      setDoc(doc(admin(), "earnings", "fake"), { driverId: NEAR_DRIVER, netPayout: 1000 })
    );
  });
});

describe("users and roles", () => {
  test("a user cannot read another user's profile", async () => {
    await assertFails(getDoc(doc(rider(OTHER_RIDER), "users", RIDER)));
  });

  test("a user cannot promote themselves to admin", async () => {
    await assertFails(
      updateDoc(doc(rider(), "users", RIDER), { role: "admin" })
    );
  });

  test("a suspended-status change is admin-only", async () => {
    await assertFails(updateDoc(doc(rider(), "users", RIDER), { status: "suspended" }));
    await assertSucceeds(
      updateDoc(doc(admin(), "users", RIDER), { status: "suspended" })
    );
  });

  test("a new driver application must start pending", async () => {
    await assertFails(
      setDoc(doc(driver(FAR_DRIVER), "drivers", FAR_DRIVER), {
        name: "Sneaky",
        approvalStatus: "approved",
      })
    );
    await assertSucceeds(
      setDoc(doc(driver(FAR_DRIVER), "drivers", FAR_DRIVER), {
        name: "Honest",
        approvalStatus: "pending",
      })
    );
  });
});

describe("pricing config", () => {
  test("a signed-in user can read pricing", async () => {
    await assertSucceeds(getDoc(doc(rider(), "config", "pricing")));
  });

  test("a rider cannot change pricing", async () => {
    await assertFails(setDoc(doc(rider(), "config", "pricing"), { commissionPct: 0 }));
  });

  test("an admin can change pricing", async () => {
    await assertSucceeds(
      setDoc(doc(admin(), "config", "pricing"), { currency: "GBP", commissionPct: 15 })
    );
  });
});
