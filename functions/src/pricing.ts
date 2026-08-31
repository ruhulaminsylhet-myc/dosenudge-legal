import { getFirestore } from "firebase-admin/firestore";
import { DEFAULT_PRICING, type Fare, type LatLng, type PricingConfig } from "./types.js";

export async function getPricing(): Promise<PricingConfig> {
  const snap = await getFirestore().doc("config/pricing").get();
  if (!snap.exists) return DEFAULT_PRICING;
  return { ...DEFAULT_PRICING, ...(snap.data() as Partial<PricingConfig>) };
}

const round2 = (n: number): number => Math.round(n * 100) / 100;

export function computeFare(
  distanceKm: number,
  durationMin: number,
  p: PricingConfig
): Fare {
  const base = p.baseFare;
  const distanceCharge = round2(distanceKm * p.perKm);
  const timeCharge = round2(durationMin * p.perMin);
  const total = round2(Math.max(base + distanceCharge + timeCharge, p.minimumFare));
  const commission = round2(total * (p.commissionPct / 100));
  return {
    currency: p.currency,
    base,
    distanceCharge,
    timeCharge,
    total,
    commission,
    driverPayout: round2(total - commission),
  };
}

const EARTH_RADIUS_KM = 6371;

export function haversineKm(a: LatLng, b: LatLng): number {
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const s =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.sqrt(s));
}

// Straight-line distance inflated to approximate road distance, and an
// average urban speed of 30 km/h for the duration estimate.
const ROAD_FACTOR = 1.3;
const AVG_SPEED_KMH = 30;

export function estimateTrip(pickup: LatLng, dropoff: LatLng): {
  distanceKm: number;
  durationMin: number;
} {
  const distanceKm = round2(haversineKm(pickup, dropoff) * ROAD_FACTOR);
  const durationMin = Math.max(1, Math.round((distanceKm / AVG_SPEED_KMH) * 60));
  return { distanceKm, durationMin };
}
