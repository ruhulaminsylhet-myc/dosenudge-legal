import type { Timestamp, GeoPoint } from "firebase-admin/firestore";

export type UserRole = "rider" | "driver" | "admin";
export type UserStatus = "active" | "suspended";
export type ApprovalStatus = "pending" | "approved" | "rejected";

export type RideStatus =
  | "requested"
  | "accepted"
  | "arrived"
  | "in_progress"
  | "completed"
  | "cancelled"
  | "expired";

export interface UserDoc {
  role: UserRole;
  status: UserStatus;
  name: string;
  phone: string;
  email: string;
  photoUrl?: string;
  fcmToken?: string;
  createdAt: Timestamp;
}

export interface Vehicle {
  make: string;
  model: string;
  color: string;
  plate: string;
  type: "standard" | "executive" | "xl";
}

export interface DriverDoc {
  name: string;
  phone: string;
  approvalStatus: ApprovalStatus;
  isOnline: boolean;
  vehicle: Vehicle;
  location?: GeoPoint;
  geohash?: string;
  fcmToken?: string;
  rating: number;
  ratingCount: number;
  totalRides: number;
  totalEarnings: number;
  /** Uploaded verification documents, keyed by type. */
  documents?: Record<string, DriverDocumentEntry>;
  /**
   * Set when a required document expired and the driver was taken off the road.
   * Cleared by the admin re-approving after fresh paperwork.
   */
  expiryBlocked?: boolean;
  /** Day of the last expiry warning push, so drivers aren't nagged hourly. */
  expiryWarnedOn?: string;
  /** Stripe Connect account; server-written only. */
  stripeAccountId?: string;
  payoutsEnabled?: boolean;
  updatedAt: Timestamp;
}

export interface DriverDocumentEntry {
  url: string;
  /** ISO yyyy-mm-dd. Absent for documents that don't expire, e.g. a photo. */
  expiresAt?: string;
}

/** Documents that legally must be in date for the driver to work. */
export const EXPIRING_DOCUMENTS = ["licence", "insurance"] as const;

export type PaymentStatus = "pending" | "paid" | "failed";

export interface RidePayment {
  status: PaymentStatus;
  provider: "stripe";
  checkoutSessionId?: string;
  paymentIntentId?: string | null;
  amount: number;
  currency: string;
  paidAt?: Timestamp;
}

export interface LatLng {
  lat: number;
  lng: number;
}

export interface RidePoint extends LatLng {
  address: string;
}

export interface Fare {
  currency: string;
  base: number;
  distanceCharge: number;
  timeCharge: number;
  total: number;
  commission: number;
  driverPayout: number;
}

export interface RideDoc {
  riderId: string;
  riderName: string;
  driverId: string | null;
  status: RideStatus;
  pickup: RidePoint;
  dropoff: RidePoint;
  estimatedDistanceKm: number;
  estimatedDurationMin: number;
  /** Distance the driver's app actually measured during the trip, in km. */
  meteredDistanceKm?: number;
  fareEstimate: Fare | null;
  finalFare: Fare | null;
  offeredTo: string[];
  requestedAt: Timestamp;
  acceptedAt?: Timestamp;
  startedAt?: Timestamp;
  completedAt?: Timestamp;
  cancelledBy?: "rider" | "driver" | "system" | "admin";
  /** Written by the server when a late rider cancellation is chargeable. */
  cancellationCharge?: CancellationCharge;
  rating?: number;
  /** Set once the rider starts checkout; only the webhook marks it paid. */
  payment?: RidePayment;
  /**
   * Denormalised driver fields the rider may see; written on accept and, for
   * the phone number, removed again once the ride reaches a terminal state.
   */
  driverInfo?: {
    name: string;
    vehicleLabel: string;
    rating: number;
    ratingCount: number;
    phone?: string;
  } | null;
  /** Rider's number, so the driver can call at pickup. Removed with the above. */
  riderPhone?: string;
}

/**
 * A late-cancellation fee. Shaped like a mini Fare so the checkout and the
 * earnings ledger can treat it the same way as a completed trip.
 */
export interface CancellationCharge {
  currency: string;
  amount: number;
  commission: number;
  driverPayout: number;
  /** Seconds between the driver accepting and the rider cancelling. */
  afterSec: number;
}

export interface PricingConfig {
  currency: string; // ISO 4217, e.g. "GBP" — never hardcoded in app code
  baseFare: number;
  perKm: number;
  perMin: number;
  minimumFare: number;
  commissionPct: number; // platform cut, e.g. 15
  searchRadiusKm: number;
  maxDriversNotified: number;
  requestTimeoutSec: number;
  /**
   * Charged to a rider who cancels after a driver has already set off, and
   * passed to that driver (minus commission) as compensation. 0 disables it.
   */
  cancellationFee: number;
  /**
   * Grace period after a driver accepts, in seconds, during which cancelling
   * is free. Long enough for an accidental request; short enough that the
   * driver isn't halfway there.
   */
  freeCancellationSec: number;
  /**
   * Ceiling on billable distance as a multiple of the straight-line pickup →
   * dropoff distance. The driver's app reports the metered distance, so this
   * caps what an inflated reading can charge a rider. 2.5 comfortably covers
   * one-way systems and diversions.
   */
  maxRouteFactor: number;
}

export const DEFAULT_PRICING: PricingConfig = {
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
};
