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
  /** Verification document download URLs, keyed by document type. */
  documents?: Record<string, string>;
}

export const DRIVER_DOCUMENT_LABELS: Record<string, string> = {
  licence: "Licence",
  insurance: "Insurance",
  vehiclePhoto: "Vehicle",
};

export interface Fare {
  currency: string;
  total: number;
  commission: number;
  driverPayout: number;
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
  fareEstimate: Fare | null;
  finalFare: Fare | null;
  requestedAt?: Timestamp;
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
}
