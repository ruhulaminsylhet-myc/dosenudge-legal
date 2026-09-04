"use client";

import { useEffect, useState } from "react";
import { collection, onSnapshot, orderBy, query } from "firebase/firestore";
import { callSetDriverApproval, firestore } from "@/lib/firebase";
import { DRIVER_DOCUMENT_LABELS, type ApprovalStatus, type DriverDoc } from "@/lib/types";
import { StatusBadge } from "@/components/StatusBadge";

export default function DriversPage() {
  const [drivers, setDrivers] = useState<DriverDoc[]>([]);
  const [filter, setFilter] = useState<ApprovalStatus | "all">("all");
  const [busyId, setBusyId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const q = query(collection(firestore(), "drivers"), orderBy("updatedAt", "desc"));
    return onSnapshot(
      q,
      (snap) =>
        setDrivers(
          snap.docs.map((d) => ({ id: d.id, ...(d.data() as Omit<DriverDoc, "id">) }))
        ),
      (e) => setError(String(e))
    );
  }, []);

  async function setApproval(driverId: string, approvalStatus: ApprovalStatus) {
    setBusyId(driverId);
    setError(null);
    try {
      await callSetDriverApproval({ driverId, approvalStatus });
    } catch (e) {
      setError(`Action failed: ${String(e)}`);
    } finally {
      setBusyId(null);
    }
  }

  const visible =
    filter === "all" ? drivers : drivers.filter((d) => d.approvalStatus === filter);

  return (
    <div>
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold">Drivers</h2>
        <div className="flex gap-1">
          {(["all", "pending", "approved", "rejected"] as const).map((f) => (
            <button
              key={f}
              onClick={() => setFilter(f)}
              className={`rounded-lg px-3 py-1.5 text-sm ${
                filter === f
                  ? "bg-blue-600 text-white"
                  : "bg-white text-slate-600 hover:bg-slate-100"
              }`}
            >
              {f}
            </button>
          ))}
        </div>
      </div>

      {error && <p className="mt-3 text-sm text-red-600">{error}</p>}

      <div className="mt-4 overflow-x-auto rounded-2xl border border-slate-200 bg-white shadow-sm">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">Driver</th>
              <th className="px-4 py-3">Vehicle</th>
              <th className="px-4 py-3">Documents</th>
              <th className="px-4 py-3">Approval</th>
              <th className="px-4 py-3">Online</th>
              <th className="px-4 py-3">Rides</th>
              <th className="px-4 py-3">Rating</th>
              <th className="px-4 py-3">Actions</th>
            </tr>
          </thead>
          <tbody>
            {visible.map((d) => (
              <tr key={d.id} className="border-b border-slate-100 last:border-0">
                <td className="px-4 py-3">
                  <p className="font-medium">{d.name}</p>
                  <p className="text-xs text-slate-500">{d.phone}</p>
                </td>
                <td className="px-4 py-3">
                  {d.vehicle
                    ? `${d.vehicle.color} ${d.vehicle.make} ${d.vehicle.model} · ${d.vehicle.plate}`
                    : "—"}
                </td>
                <td className="px-4 py-3">
                  {d.documents && Object.keys(d.documents).length > 0 ? (
                    <div className="flex flex-wrap gap-1">
                      {Object.entries(d.documents).map(([key, url]) => (
                        <a
                          key={key}
                          href={url}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="rounded-full bg-blue-50 px-2.5 py-0.5 text-xs font-medium text-blue-700 hover:bg-blue-100"
                        >
                          {DRIVER_DOCUMENT_LABELS[key] ?? key}
                        </a>
                      ))}
                    </div>
                  ) : (
                    <span className="text-xs text-amber-600">None uploaded</span>
                  )}
                </td>
                <td className="px-4 py-3">
                  <StatusBadge value={d.approvalStatus} />
                </td>
                <td className="px-4 py-3">
                  <StatusBadge value={d.isOnline ? "online" : "offline"} />
                </td>
                <td className="px-4 py-3">{d.totalRides ?? 0}</td>
                <td className="px-4 py-3">
                  {d.ratingCount ? `${d.rating.toFixed(1)} ⭐` : "—"}
                </td>
                <td className="px-4 py-3">
                  <div className="flex gap-2">
                    {d.approvalStatus !== "approved" && (
                      <button
                        disabled={busyId === d.id}
                        onClick={() => setApproval(d.id, "approved")}
                        className="rounded-lg bg-emerald-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-emerald-700 disabled:opacity-50"
                      >
                        Approve
                      </button>
                    )}
                    {d.approvalStatus !== "rejected" && (
                      <button
                        disabled={busyId === d.id}
                        onClick={() => setApproval(d.id, "rejected")}
                        className="rounded-lg bg-red-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-red-700 disabled:opacity-50"
                      >
                        Reject
                      </button>
                    )}
                  </div>
                </td>
              </tr>
            ))}
            {visible.length === 0 && (
              <tr>
                <td colSpan={8} className="px-4 py-8 text-center text-slate-500">
                  No drivers found.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
