"use client";

import { useEffect, useState } from "react";
import {
  collection,
  limit,
  onSnapshot,
  orderBy,
  query,
} from "firebase/firestore";
import { firestore } from "@/lib/firebase";
import type { RideDoc, RideStatus } from "@/lib/types";
import { StatusBadge } from "@/components/StatusBadge";

const ACTIVE: RideStatus[] = ["requested", "accepted", "arrived", "in_progress"];

export default function RidesPage() {
  const [rides, setRides] = useState<RideDoc[]>([]);
  const [tab, setTab] = useState<"active" | "all">("active");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const q = query(
      collection(firestore(), "rides"),
      orderBy("requestedAt", "desc"),
      limit(100)
    );
    return onSnapshot(
      q,
      (snap) =>
        setRides(
          snap.docs.map((d) => ({ id: d.id, ...(d.data() as Omit<RideDoc, "id">) }))
        ),
      (e) => setError(String(e))
    );
  }, []);

  const visible =
    tab === "active" ? rides.filter((r) => ACTIVE.includes(r.status)) : rides;

  return (
    <div>
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold">Rides (live)</h2>
        <div className="flex gap-1">
          {(["active", "all"] as const).map((t) => (
            <button
              key={t}
              onClick={() => setTab(t)}
              className={`rounded-lg px-3 py-1.5 text-sm ${
                tab === t
                  ? "bg-blue-600 text-white"
                  : "bg-white text-slate-600 hover:bg-slate-100"
              }`}
            >
              {t}
            </button>
          ))}
        </div>
      </div>

      {error && <p className="mt-3 text-sm text-red-600">{error}</p>}

      <div className="mt-4 overflow-x-auto rounded-2xl border border-slate-200 bg-white shadow-sm">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">Time</th>
              <th className="px-4 py-3">Rider</th>
              <th className="px-4 py-3">Route</th>
              <th className="px-4 py-3">Distance</th>
              <th className="px-4 py-3">Fare</th>
              <th className="px-4 py-3">Payment</th>
              <th className="px-4 py-3">Status</th>
            </tr>
          </thead>
          <tbody>
            {visible.map((r) => {
              const fare = r.finalFare ?? r.fareEstimate;
              return (
                <tr key={r.id} className="border-b border-slate-100 last:border-0">
                  <td className="px-4 py-3 whitespace-nowrap text-slate-500">
                    {r.requestedAt?.toDate().toLocaleString() ?? "—"}
                  </td>
                  <td className="px-4 py-3 font-medium">{r.riderName}</td>
                  <td className="px-4 py-3">
                    <p className="max-w-56 truncate">{r.pickup?.address}</p>
                    <p className="max-w-56 truncate text-xs text-slate-500">
                      → {r.dropoff?.address}
                    </p>
                  </td>
                  <td className="px-4 py-3 whitespace-nowrap">
                    {r.billedDistanceKm ? (
                      <>
                        {r.billedDistanceKm} km
                        <span className="ml-1 text-xs text-slate-400">
                          metered
                        </span>
                      </>
                    ) : r.estimatedDistanceKm ? (
                      `${r.estimatedDistanceKm} km`
                    ) : (
                      "—"
                    )}
                  </td>
                  <td className="px-4 py-3 whitespace-nowrap">
                    {fare ? `${fare.currency} ${fare.total.toFixed(2)}` : "—"}
                    {r.finalFare && (
                      <span className="ml-1 text-xs text-emerald-600">final</span>
                    )}
                  </td>
                  <td className="px-4 py-3">
                    {r.payment ? (
                      <StatusBadge value={r.payment.status} />
                    ) : (
                      <span className="text-xs text-slate-400">cash</span>
                    )}
                  </td>
                  <td className="px-4 py-3">
                    <StatusBadge value={r.status} />
                  </td>
                </tr>
              );
            })}
            {visible.length === 0 && (
              <tr>
                <td colSpan={7} className="px-4 py-8 text-center text-slate-500">
                  No rides here yet.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
