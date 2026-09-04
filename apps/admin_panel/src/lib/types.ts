import type { Timestamp, GeoPoint } from "firebase/firestore";

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
  id: string;
  role: UserRole;
  status: UserStatus;
  name: string;
  phone: string;
  email: string;
  photoUrl?: string;
  createdAt?: Timestamp;
}

export interface Vehicle {
  make: string;
  model: string;
  color: string;
  plate: string;
  type: string;
}

export interface DriverDoc {
  id: string;
  name: string;
  phone: string;
  approvalStatus: ApprovalStatus;
  isOnline: boolean;
  vehicle: Vehicle;
  location?: GeoPoint;
  rating: number;
  ratingCount: number;
  totalRides: number;
  totalEarnings: number;
  /** Verification documents, keyed by document type. */
  documents?: Record<string, DriverDocumentEntry>;
  /** Server-set when an expired document took the driver off the road. */
  expiryBlocked?: boolean;
}

export interface DriverDocumentEntry {
  url: string;
  /** ISO yyyy-mm-dd. Absent for documents that don't expire. */
  expiresAt?: string;
}

export const DRIVER_DOCUMENT_LABELS: Record<string, string> = {
  licence: "Licence",
  insurance: "Insurance",
  vehiclePhoto: "Vehicle",
};

/** Documents the driver may not work without an in-date copy of. */
export const EXPIRING_DOCUMENTS = ["licence", "insurance"] as const;

/** Whole days until an ISO date; negative once past. */
export function daysUntil(isoDate: string): number {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  return Math.round(
    (new Date(`${isoDate}T00:00:00`).getTime() - today.getTime()) / 86_400_000
  );
}

export interface Fare {
  currency: string;
  total: number;
  commission: number;
  driverPayout: number;
}

export interface RidePayment {
  status: "pending" | "paid" | "failed";
  amount: number;
  currency: string;
}

export interface RideDoc {
  id: string;
  riderId: string;
  riderName: string;
  driverId: string | null;
  status: RideStatus;
  pickup: { address: string };
  dropoff: { address: string };
  estimatedDistanceKm: number;
  /** Distance actually charged for, once the trip's GPS meter is clamped. */
  billedDistanceKm?: number;
  fareEstimate: Fare | null;
  finalFare: Fare | null;
  requestedAt?: Timestamp;
  payment?: RidePayment;
}

export interface PricingConfig {
  currency: string;
  baseFare: number;
  perKm: number;
  perMin: number;
  minimumFare: number;
  commissionPct: number;
  searchRadiusKm: number;
  maxDriversNotified: number;
  requestTimeoutSec: number;
  maxRouteFactor: number;
}
