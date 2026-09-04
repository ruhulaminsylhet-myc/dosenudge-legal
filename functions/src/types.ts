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
  documents?: Record<string, string>;
  /** Stripe Connect account; server-written only. */
  stripeAccountId?: string;
  payoutsEnabled?: boolean;
  updatedAt: Timestamp;
}

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
  maxRouteFactor: 2.5,
};
