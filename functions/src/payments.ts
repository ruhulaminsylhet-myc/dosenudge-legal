import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions/v2";
import { defineSecret } from "firebase-functions/params";
import { HttpsError, onCall, onRequest } from "firebase-functions/v2/https";
import Stripe from "stripe";

import type { DriverDoc, RideDoc } from "./types.js";

// Set with:
//   firebase functions:secrets:set STRIPE_SECRET_KEY
//   firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
const STRIPE_SECRET_KEY = defineSecret("STRIPE_SECRET_KEY");
const STRIPE_WEBHOOK_SECRET = defineSecret("STRIPE_WEBHOOK_SECRET");

// Where Stripe sends the driver back after onboarding and the rider after
// checkout. Set to your admin panel / marketing domain.
//   firebase functions:config is deprecated; use an env var in .env instead:
//   PUBLIC_RETURN_URL=https://yourdomain.com
const returnBase = () =>
  process.env.PUBLIC_RETURN_URL?.replace(/\/$/, "") ?? "https://example.com";

const db = () => getFirestore();

function stripe(): Stripe {
  return new Stripe(STRIPE_SECRET_KEY.value(), {
    // Pin the API version so a Stripe-side upgrade can't change behaviour silently.
    apiVersion: "2026-08-26.dahlia",
  });
}

/** Stripe works in minor units; our fares are stored in major units. */
const toMinorUnits = (amount: number) => Math.round(amount * 100);

function requireDriver(request: {
  auth?: { uid: string; token?: Record<string, unknown> } | null;
}): string {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  if (request.auth.token?.role !== "driver") {
    throw new HttpsError("permission-denied", "Drivers only.");
  }
  return request.auth.uid;
}

// ---------------------------------------------------------------------------
// Driver payouts (Stripe Connect Express)
// ---------------------------------------------------------------------------

/**
 * Creates the driver's Connect account if they don't have one, and returns a
 * fresh onboarding link. Account links expire, so the app calls this each time
 * the driver taps "set up payouts" rather than storing the URL.
 */
export const createDriverPayoutAccount = onCall(
  { secrets: [STRIPE_SECRET_KEY] },
  async (request) => {
    const uid = requireDriver(request);
    const driverRef = db().doc(`drivers/${uid}`);
    const snap = await driverRef.get();
    const driver = snap.data() as DriverDoc | undefined;
    if (!driver) throw new HttpsError("not-found", "Driver profile not found.");
    if (driver.approvalStatus !== "approved") {
      throw new HttpsError(
        "failed-precondition",
        "Your application must be approved before setting up payouts."
      );
    }

    const client = stripe();
    let accountId = driver.stripeAccountId;

    if (!accountId) {
      const account = await client.accounts.create({
        type: "express",
        business_type: "individual",
        capabilities: { transfers: { requested: true } },
        metadata: { driverId: uid },
      });
      accountId = account.id;
      await driverRef.update({
        stripeAccountId: accountId,
        payoutsEnabled: false,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    const link = await client.accountLinks.create({
      account: accountId,
      type: "account_onboarding",
      refresh_url: `${returnBase()}/payouts/refresh`,
      return_url: `${returnBase()}/payouts/done`,
    });

    logger.info("payout onboarding link issued", { uid, accountId });
    return { url: link.url };
  }
);

/**
 * Pulls the current capability state from Stripe. Onboarding finishes in a
 * browser, so the app calls this on return rather than waiting for the webhook.
 */
export const refreshDriverPayoutStatus = onCall(
  { secrets: [STRIPE_SECRET_KEY] },
  async (request) => {
    const uid = requireDriver(request);
    const driverRef = db().doc(`drivers/${uid}`);
    const driver = (await driverRef.get()).data() as DriverDoc | undefined;
    if (!driver?.stripeAccountId) return { payoutsEnabled: false };

    const account = await stripe().accounts.retrieve(driver.stripeAccountId);
    const payoutsEnabled = account.charges_enabled && account.payouts_enabled;
    await driverRef.update({
      payoutsEnabled,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { payoutsEnabled };
  }
);

// ---------------------------------------------------------------------------
// Rider payment
// ---------------------------------------------------------------------------

/**
 * Opens a Stripe Checkout session for a completed, unpaid ride. The platform
 * commission is taken as an application fee and the remainder is transferred to
 * the driver's connected account, so payouts need no separate bookkeeping.
 */
/**
 * What the rider owes on this ride, if anything: the fare of a completed trip,
 * or the fee for a late cancellation. Both amounts are written by the server —
 * nothing here is taken from the client.
 */
function billableCharge(
  ride: RideDoc
): { amount: number; commission: number; currency: string; name: string } | null {
  if (ride.status === "completed" && ride.finalFare) {
    return {
      amount: ride.finalFare.total,
      commission: ride.finalFare.commission,
      currency: ride.finalFare.currency,
      name: "Taxi fare",
    };
  }
  if (ride.status === "cancelled" && ride.cancellationCharge) {
    const c = ride.cancellationCharge;
    return {
      amount: c.amount,
      commission: c.commission,
      currency: c.currency,
      name: "Cancellation fee",
    };
  }
  return null;
}

export const createRideCheckout = onCall(
  { secrets: [STRIPE_SECRET_KEY] },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
    const { rideId } = request.data as { rideId: string };
    if (!rideId) throw new HttpsError("invalid-argument", "rideId is required.");

    const rideRef = db().doc(`rides/${rideId}`);
    const ride = (await rideRef.get()).data() as RideDoc | undefined;
    if (!ride) throw new HttpsError("not-found", "Ride not found.");
    if (ride.riderId !== request.auth.uid) {
      throw new HttpsError("permission-denied", "This is not your ride.");
    }
    if (ride.payment?.status === "paid") {
      throw new HttpsError("already-exists", "This ride is already paid.");
    }

    // Two things a rider can owe: the fare for a trip they took, or the fee
    // for cancelling one after the driver had set off. Both are server-written
    // and both pay out to the same driver, so they share this flow.
    const charge = billableCharge(ride);
    if (!charge) {
      throw new HttpsError(
        "failed-precondition",
        ride.status === "completed"
          ? "The final fare is not ready yet."
          : "There is nothing to pay on this ride."
      );
    }

    const driver = ride.driverId
      ? ((await db().doc(`drivers/${ride.driverId}`).get()).data() as
          | DriverDoc
          | undefined)
      : undefined;
    if (!driver?.stripeAccountId || !driver.payoutsEnabled) {
      throw new HttpsError(
        "failed-precondition",
        "Your driver has not finished setting up payouts. Please pay in cash."
      );
    }

    const session = await stripe().checkout.sessions.create({
      mode: "payment",
      // Stripe emails the receipt; the app only needs the hosted URL.
      line_items: [
        {
          quantity: 1,
          price_data: {
            currency: charge.currency.toLowerCase(),
            unit_amount: toMinorUnits(charge.amount),
            product_data: {
              name: charge.name,
              description: `${ride.pickup.address} → ${ride.dropoff.address}`,
            },
          },
        },
      ],
      payment_intent_data: {
        application_fee_amount: toMinorUnits(charge.commission),
        transfer_data: { destination: driver.stripeAccountId },
        metadata: { rideId, riderId: ride.riderId, driverId: ride.driverId ?? "" },
      },
      metadata: { rideId },
      success_url: `${returnBase()}/pay/done?ride=${rideId}`,
      cancel_url: `${returnBase()}/pay/cancelled?ride=${rideId}`,
    });

    await rideRef.update({
      payment: {
        status: "pending",
        provider: "stripe",
        checkoutSessionId: session.id,
        amount: charge.amount,
        currency: charge.currency,
      },
    });

    logger.info("checkout session created", { rideId, sessionId: session.id });
    return { url: session.url };
  }
);

// ---------------------------------------------------------------------------
// Webhook
// ---------------------------------------------------------------------------

/**
 * Stripe is the source of truth for whether money moved, so payment status is
 * only ever set from a signature-verified webhook — never from the client
 * returning to the success URL.
 *
 * Register the deployed URL in the Stripe dashboard for these events:
 *   checkout.session.completed, checkout.session.async_payment_failed,
 *   account.updated
 */
export const stripeWebhook = onRequest(
  { secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] },
  async (req, res) => {
    const signature = req.headers["stripe-signature"];
    if (typeof signature !== "string") {
      res.status(400).send("Missing stripe-signature header.");
      return;
    }

    let event: Stripe.Event;
    try {
      event = stripe().webhooks.constructEvent(
        // onRequest keeps the unparsed body, which signature checking needs.
        req.rawBody,
        signature,
        STRIPE_WEBHOOK_SECRET.value()
      );
    } catch (err) {
      logger.warn("rejected webhook with bad signature", { error: String(err) });
      res.status(400).send("Invalid signature.");
      return;
    }

    try {
      switch (event.type) {
        case "checkout.session.completed": {
          const session = event.data.object;
          const rideId = session.metadata?.rideId;
          if (!rideId) break;
          await db().doc(`rides/${rideId}`).update({
            "payment.status": "paid",
            "payment.paidAt": FieldValue.serverTimestamp(),
            "payment.paymentIntentId":
              typeof session.payment_intent === "string"
                ? session.payment_intent
                : (session.payment_intent?.id ?? null),
          });
          logger.info("ride paid", { rideId });
          break;
        }

        case "checkout.session.async_payment_failed":
        case "checkout.session.expired": {
          const rideId = event.data.object.metadata?.rideId;
          if (!rideId) break;
          await db().doc(`rides/${rideId}`).update({ "payment.status": "failed" });
          logger.info("ride payment failed", { rideId, reason: event.type });
          break;
        }

        // Fires when a driver finishes (or later loses) Connect onboarding.
        case "account.updated": {
          const account = event.data.object;
          const driverId = account.metadata?.driverId;
          if (!driverId) break;
          await db().doc(`drivers/${driverId}`).update({
            payoutsEnabled: account.charges_enabled && account.payouts_enabled,
            updatedAt: FieldValue.serverTimestamp(),
          });
          logger.info("driver payout capability updated", {
            driverId,
            payoutsEnabled: account.payouts_enabled,
          });
          break;
        }

        default:
          break;
      }
    } catch (err) {
      // Returning 500 makes Stripe retry, which is what we want for a
      // transient Firestore failure.
      logger.error("webhook handler failed", { type: event.type, error: String(err) });
      res.status(500).send("Handler failed.");
      return;
    }

    res.status(200).send("ok");
  }
);
