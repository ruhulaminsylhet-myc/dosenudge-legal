"use client";

import { useEffect, useState } from "react";
import {
  collection,
  getCountFromServer,
  query,
  where,
} from "firebase/firestore";
import { firestore } from "@/lib/firebase";

interface Stats {
  totalUsers: number;
  totalDrivers: number;
  pendingDrivers: number;
  onlineDrivers: number;
  activeRides: number;
  completedRides: number;
}

export default function DashboardPage() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function load() {
      try {
        const users = collection(firestore(), "users");
        const drivers = collection(firestore(), "drivers");
        const rides = collection(firestore(), "rides");
        const [u, d, pd, od, ar, cr] = await Promise.all([
          getCountFromServer(users),
          getCountFromServer(drivers),
          getCountFromServer(
            query(drivers, where("approvalStatus", "==", "pending"))
          ),
          getCountFromServer(query(drivers, where("isOnline", "==", true))),
          getCountFromServer(
            query(rides, where("status", "in", ["requested", "accepted", "arrived", "in_progress"]))
          ),
          getCountFromServer(query(rides, where("status", "==", "completed"))),
        ]);
        setStats({
          totalUsers: u.data().count,
          totalDrivers: d.data().count,
          pendingDrivers: pd.data().count,
          onlineDrivers: od.data().count,
          activeRides: ar.data().count,
          completedRides: cr.data().count,
        });
      } catch (e) {
        setError(`Failed to load stats: ${String(e)}`);
      }
    }
    load();
  }, []);

  if (error) return <p className="text-red-600">{error}</p>;
  if (!stats) return <p className="text-slate-500">Loading stats…</p>;

  const cards = [
    { label: "Total users", value: stats.totalUsers },
    { label: "Total drivers", value: stats.totalDrivers },
    { label: "Pending approvals", value: stats.pendingDrivers, alert: stats.pendingDrivers > 0 },
    { label: "Drivers online", value: stats.onlineDrivers },
    { label: "Active rides", value: stats.activeRides },
    { label: "Completed rides", value: stats.completedRides },
  ];

  return (
    <div>
      <h2 className="text-lg font-semibold">Overview</h2>
      <div className="mt-4 grid grid-cols-2 gap-4 md:grid-cols-3">
        {cards.map((c) => (
          <div
            key={c.label}
            className={`rounded-2xl border bg-white p-5 shadow-sm ${
              c.alert ? "border-amber-300" : "border-slate-200"
            }`}
          >
            <p className="text-sm text-slate-500">{c.label}</p>
            <p className="mt-1 text-3xl font-semibold">{c.value}</p>
          </div>
        ))}
      </div>
    </div>
  );
}
