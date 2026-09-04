import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import {
  FieldValue,
  getFirestore,
  Timestamp,
  type Query,
} from "firebase-admin/firestore";
import { logger, setGlobalOptions } from "firebase-functions/v2";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as geofire from "geofire-common";

import { computeFare, estimateTrip, getPricing } from "./pricing.js";
import { sendPush, sendPushMulti } from "./notify.js";
import type {
  ApprovalStatus,
  DriverDoc,
  LatLng,
  RideDoc,
  UserDoc,
  UserStatus,
} from "./types.js";

initializeApp();
setGlobalOptions({ region: "europe-west2", maxInstances: 10 });

const db = () => getFirestore();

// ---------------------------------------------------------------------------
// Role claims: set { role } when a user profile is created. Clients can only
// create their own users doc with role rider|driver (enforced by rules), and
// admin can never be self-assigned here.
// ---------------------------------------------------------------------------
export const onUserCreated = onDocumentCreated("users/{uid}", async (event) => {
  const data = event.data?.data() as UserDoc | undefined;
  if (!data) return;
  const uid = event.params.uid;
  if (data.role !== "rider" && data.role !== "driver") {
    logger.warn("users doc created with invalid role; skipping claim", { uid });
    return;
  }
  const auth = getAuth();
  const user = await auth.getUser(uid);
  await auth.setCustomUserClaims(uid, {
    ...(user.customClaims ?? {}),
    role: data.role,
  });
  logger.info("role claim set", { uid, role: data.role });
});

// ---------------------------------------------------------------------------
// Ride lifecycle
// ---------------------------------------------------------------------------
export const onRideCreated = onDocumentCreated("rides/{rideId}", async (event) => {
  const snap = event.data;
  if (!snap) return;
  const ride = snap.data() as RideDoc;
  const rideId = event.params.rideId;

  // Block suspended riders even though rules let them write the doc.
  const riderSnap = await db().doc(`users/${ride.riderId}`).get();
  const rider = riderSnap.data() as UserDoc | undefined;
  if (!rider || rider.status !== "active") {
    await snap.ref.update({
      status: "cancelled",
      cancelledBy: "system",
      cancelReason: "rider_suspended",
    });
    return;
  }

  const pricing = await getPricing();
  const trip = estimateTrip(ride.pickup, ride.dropoff);
  const fareEstimate = computeFare(trip.distanceKm, trip.durationMin, pricing);

  // Geohash query for nearby online, approved drivers.
  const center: [number, number] = [ride.pickup.lat, ride.pickup.lng];
  const radiusM = pricing.searchRadiusKm * 1000;
  const bounds = geofire.geohashQueryBounds(center, radiusM);

  const queries = bounds.map((b) => {
    const q: Query = db()
      .collection("drivers")
      .where("approvalStatus", "==", "approved")
      .where("isOnline", "==", true)
      .orderBy("geohash")
      .startAt(b[0])
      .endAt(b[1]);
    return q.get();
  });

  const snapshots = await Promise.all(queries);
  const candidates: { id: string; distanceM: number; token?: string }[] = [];
  for (const qs of snapshots) {
    for (const doc of qs.docs) {
      const d = doc.data() as DriverDoc;
      if (!d.location) continue;
      const distanceM =
        geofire.distanceBetween(
          [d.location.latitude, d.location.longitude],
          center
        ) * 1000;
      if (distanceM <= radiusM) {
        candidates.push({ id: doc.id, distanceM, token: d.fcmToken });
      }
    }
  }
  candidates.sort((a, b) => a.distanceM - b.distanceM);
  const offered = candidates.slice(0, pricing.maxDriversNotified);

  await snap.ref.update({
    fareEstimate,
    estimatedDistanceKm: trip.distanceKm,
    estimatedDurationMin: trip.durationMin,
    offeredTo: offered.map((c) => c.id),
  });

  if (offered.length === 0) {
    logger.info("no drivers available", { rideId });
    await sendPush(rider.fcmToken, {
      title: "Finding you a driver…",
      body: "No drivers are nearby right now. We'll keep looking.",
      data: { type: "ride_searching", rideId },
    });
    return;
  }

  await sendPushMulti(
    offered.map((c) => c.token ?? ""),
    {
      title: "New ride request",
      body: `Pickup: ${ride.pickup.address} → ${ride.dropoff.address} · est. ${fareEstimate.currency} ${fareEstimate.total.toFixed(2)}`,
      data: { type: "ride_request", rideId },
    }
  );
  logger.info("ride offered to drivers", { rideId, count: offered.length });
});

export const onRideUpdated = onDocumentUpdated("rides/{rideId}", async (event) => {
  const before = event.data?.before.data() as RideDoc | undefined;
  const after = event.data?.after.data() as RideDoc | undefined;
  if (!before || !after || before.status === after.status) return;
  const rideId = event.params.rideId;
  const ref = event.data!.after.ref;

  const riderSnap = await db().doc(`users/${after.riderId}`).get();
  const riderToken = (riderSnap.data() as UserDoc | undefined)?.fcmToken;

  switch (after.status) {
    case "accepted": {
      const driverSnap = await db().doc(`drivers/${after.driverId}`).get();
      const driver = driverSnap.data() as DriverDoc | undefined;
      const vehicle = driver
        ? `${driver.vehicle.color} ${driver.vehicle.make} ${driver.vehicle.model} (${driver.vehicle.plate})`
        : "your driver";
      // Copy the handful of driver fields the rider is entitled to see onto the
      // ride itself, so the rider app never reads the drivers collection (which
      // also holds phone numbers and live location).
      await ref.update({
        acceptedAt: FieldValue.serverTimestamp(),
        driverInfo: driver
          ? {
              name: driver.name,
              vehicleLabel: vehicle,
              rating: driver.rating ?? 0,
              ratingCount: driver.ratingCount ?? 0,
            }
          : null,
      });
      await sendPush(riderToken, {
        title: "Driver on the way",
        body: `${driver?.name ?? "Your driver"} is coming in a ${vehicle}.`,
        data: { type: "ride_accepted", rideId },
      });
      break;
    }
    case "arrived": {
      await sendPush(riderToken, {
        title: "Your driver has arrived",
        body: "Your taxi is waiting at the pickup point.",
        data: { type: "ride_arrived", rideId },
      });
      break;
    }
    case "in_progress": {
      await ref.update({ startedAt: FieldValue.serverTimestamp() });
      break;
    }
    case "completed": {
      await settleRide(rideId, after, ref);
      await sendPush(riderToken, {
        title: "Trip completed",
        body: "Thanks for riding with us. Rate your trip in the app.",
        data: { type: "ride_completed", rideId },
      });
      break;
    }
    case "cancelled": {
      if (after.driverId) {
        const driverSnap = await db().doc(`drivers/${after.driverId}`).get();
        await sendPush((driverSnap.data() as DriverDoc | undefined)?.fcmToken, {
          title: "Ride cancelled",
          body: "The ride was cancelled.",
          data: { type: "ride_cancelled", rideId },
        });
      }
      await sendPush(riderToken, {
        title: "Ride cancelled",
        body: "Your ride has been cancelled.",
        data: { type: "ride_cancelled", rideId },
      });
      break;
    }
    default:
      break;
  }
});

async function settleRide(
  rideId: string,
  ride: RideDoc,
  ref: FirebaseFirestore.DocumentReference
): Promise<void> {
  if (!ride.driverId) return;
  const pricing = await getPricing();

  // MVP settlement uses the estimated trip; upgrade path is metering actual
  // GPS distance from driver location pings.
  const startedAt = ride.startedAt?.toDate();
  const durationMin = startedAt
    ? Math.max(1, Math.round((Date.now() - startedAt.getTime()) / 60000))
    : ride.estimatedDurationMin;
  const finalFare = computeFare(ride.estimatedDistanceKm, durationMin, pricing);

  const driverRef = db().doc(`drivers/${ride.driverId}`);
  const earningsRef = db().collection("earnings").doc();

  await db().runTransaction(async (tx) => {
    tx.update(ref, {
      finalFare,
      completedAt: FieldValue.serverTimestamp(),
    });
    tx.update(driverRef, {
      totalRides: FieldValue.increment(1),
      totalEarnings: FieldValue.increment(finalFare.driverPayout),
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(earningsRef, {
      driverId: ride.driverId,
      rideId,
      currency: finalFare.currency,
      grossFare: finalFare.total,
      commission: finalFare.commission,
      netPayout: finalFare.driverPayout,
      createdAt: FieldValue.serverTimestamp(),
    });
  });
  logger.info("ride settled", { rideId, total: finalFare.total });
}

// Expire ride requests nobody accepted within the timeout window.
export const expireStaleRequests = onSchedule("every 1 minutes", async () => {
  const pricing = await getPricing();
  const cutoff = Timestamp.fromMillis(
    Date.now() - pricing.requestTimeoutSec * 1000
  );
  const stale = await db()
    .collection("rides")
    .where("status", "==", "requested")
    .where("requestedAt", "<", cutoff)
    .limit(50)
    .get();

  await Promise.all(
    stale.docs.map(async (doc) => {
      await doc.ref.update({ status: "expired", cancelledBy: "system" });
      const ride = doc.data() as RideDoc;
      const riderSnap = await db().doc(`users/${ride.riderId}`).get();
      await sendPush((riderSnap.data() as UserDoc | undefined)?.fcmToken, {
        title: "No drivers found",
        body: "We couldn't find a driver this time. Please try again.",
        data: { type: "ride_expired", rideId: doc.id },
      });
    })
  );
  if (!stale.empty) logger.info("expired stale requests", { count: stale.size });
});

// ---------------------------------------------------------------------------
// Callables
// ---------------------------------------------------------------------------
export const getFareEstimate = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const { pickup, dropoff } = request.data as { pickup: LatLng; dropoff: LatLng };
  for (const p of [pickup, dropoff]) {
    if (
      !p ||
      typeof p.lat !== "number" ||
      typeof p.lng !== "number" ||
      Math.abs(p.lat) > 90 ||
      Math.abs(p.lng) > 180
    ) {
      throw new HttpsError("invalid-argument", "Valid pickup and dropoff required.");
    }
  }
  const pricing = await getPricing();
  const trip = estimateTrip(pickup, dropoff);
  return {
    ...trip,
    fare: computeFare(trip.distanceKm, trip.durationMin, pricing),
  };
});

// Rider rates a completed trip. Ratings are server-owned: rules block clients
// from touching drivers.rating, so the running average is only ever written here.
export const rateRide = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const { rideId, rating } = request.data as { rideId: string; rating: number };
  if (!rideId || !Number.isInteger(rating) || rating < 1 || rating > 5) {
    throw new HttpsError("invalid-argument", "rideId and a rating of 1-5 are required.");
  }

  const rideRef = db().doc(`rides/${rideId}`);
  const uid = request.auth.uid;

  const driverId = await db().runTransaction(async (tx) => {
    const snap = await tx.get(rideRef);
    const ride = snap.data() as RideDoc | undefined;
    if (!ride) throw new HttpsError("not-found", "Ride not found.");
    if (ride.riderId !== uid) {
      throw new HttpsError("permission-denied", "You can only rate your own rides.");
    }
    if (ride.status !== "completed") {
      throw new HttpsError("failed-precondition", "Only completed rides can be rated.");
    }
    if (ride.rating != null) {
      throw new HttpsError("already-exists", "This ride has already been rated.");
    }
    if (!ride.driverId) {
      throw new HttpsError("failed-precondition", "This ride has no driver to rate.");
    }

    const driverRef = db().doc(`drivers/${ride.driverId}`);
    const driverSnap = await tx.get(driverRef);
    const driver = driverSnap.data() as DriverDoc | undefined;
    if (!driver) throw new HttpsError("not-found", "Driver not found.");

    // Recompute the average from the stored total rather than trusting the
    // client, so concurrent ratings can't drift the value.
    const count = driver.ratingCount ?? 0;
    const newCount = count + 1;
    const newAverage = ((driver.rating ?? 0) * count + rating) / newCount;

    tx.update(rideRef, { rating });
    tx.update(driverRef, {
      rating: Math.round(newAverage * 100) / 100,
      ratingCount: newCount,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return ride.driverId;
  });

  logger.info("ride rated", { rideId, driverId, rating });
  return { ok: true };
});

function requireAdmin(request: { auth?: { token?: Record<string, unknown> } | null }): void {
  if (request.auth?.token?.admin !== true) {
    throw new HttpsError("permission-denied", "Admin access required.");
  }
}

// Approve / reject a driver application. Approval is what unlocks going online.
export const adminSetDriverApproval = onCall(async (request) => {
  requireAdmin(request);
  const { driverId, approvalStatus } = request.data as {
    driverId: string;
    approvalStatus: ApprovalStatus;
  };
  if (!driverId || !["approved", "rejected", "pending"].includes(approvalStatus)) {
    throw new HttpsError("invalid-argument", "driverId and valid approvalStatus required.");
  }

  const driverRef = db().doc(`drivers/${driverId}`);
  const snap = await driverRef.get();
  if (!snap.exists) throw new HttpsError("not-found", "Driver not found.");

  await driverRef.update({
    approvalStatus,
    isOnline: false,
    updatedAt: FieldValue.serverTimestamp(),
  });

  const driver = snap.data() as DriverDoc;
  const messages: Record<ApprovalStatus, { title: string; body: string }> = {
    approved: {
      title: "You're approved! 🎉",
      body: "Your driver application has been approved. Go online to start earning.",
    },
    rejected: {
      title: "Application update",
      body: "Your driver application was not approved. Contact support for details.",
    },
    pending: {
      title: "Application under review",
      body: "Your driver application is being reviewed again.",
    },
  };
  await sendPush(driver.fcmToken, {
    ...messages[approvalStatus],
    data: { type: "approval_update", approvalStatus },
  });
  return { ok: true };
});

// Suspend / reactivate any user (rider or driver). Suspension also disables
// the Firebase Auth account and revokes tokens, so it takes effect everywhere.
export const adminSetUserStatus = onCall(async (request) => {
  requireAdmin(request);
  const { userId, status } = request.data as { userId: string; status: UserStatus };
  if (!userId || !["active", "suspended"].includes(status)) {
    throw new HttpsError("invalid-argument", "userId and valid status required.");
  }
  if (userId === request.auth?.uid) {
    throw new HttpsError("failed-precondition", "You cannot suspend yourself.");
  }

  const userRef = db().doc(`users/${userId}`);
  const snap = await userRef.get();
  if (!snap.exists) throw new HttpsError("not-found", "User not found.");

  const auth = getAuth();
  await auth.updateUser(userId, { disabled: status === "suspended" });
  if (status === "suspended") await auth.revokeRefreshTokens(userId);

  await userRef.update({ status });
  const driverRef = db().doc(`drivers/${userId}`);
  if ((await driverRef.get()).exists) {
    await driverRef.update({ isOnline: false, updatedAt: FieldValue.serverTimestamp() });
  }
  return { ok: true };
});

// Grant or revoke admin. Only an existing admin can call this; the very first
// admin is bootstrapped with scripts/set-admin.mjs using a service account.
export const adminGrantAdmin = onCall(async (request) => {
  requireAdmin(request);
  const { userId, admin } = request.data as { userId: string; admin: boolean };
  if (!userId || typeof admin !== "boolean") {
    throw new HttpsError("invalid-argument", "userId and admin flag required.");
  }
  if (userId === request.auth?.uid && !admin) {
    throw new HttpsError("failed-precondition", "You cannot revoke your own admin access.");
  }
  const auth = getAuth();
  const user = await auth.getUser(userId);
  await auth.setCustomUserClaims(userId, {
    ...(user.customClaims ?? {}),
    admin,
  });
  await auth.revokeRefreshTokens(userId); // force claim refresh
  return { ok: true };
});
