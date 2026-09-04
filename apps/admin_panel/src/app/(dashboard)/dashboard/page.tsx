"use client";

import { useEffect, useState } from "react";
import {
  collection,
  getAggregateFromServer,
  getCountFromServer,
  query,
  sum,
  Timestamp,
  where,
} from "firebase/firestore";
import { getDocs, limit, orderBy } from "firebase/firestore";

import { firestore } from "@/lib/firebase";

interface Stats {
  totalUsers: number;
  totalDrivers: number;
  pendingDrivers: number;
  onlineDrivers: number;
  activeRides: number;
  completedRides: number;
}

interface Revenue {
  /** Your commission — what the platform actually earned. */
  commission7d: number;
  commissionAll: number;
  /** Total fares processed, for context on the commission figure. */
  gross7d: number;
  currency: string;
}

const money = (amount: number, currency: string) =>
  new Intl.NumberFormat(undefined, {
    style: "currency",
    currency: currency || "GBP",
  }).format(amount);

export default function DashboardPage() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [revenue, setRevenue] = useState<Revenue | null>(null);
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

    // Summed server-side: the ledger only ever grows, so pulling every entry
    // into the browser to add it up would get slower every week.
    async function loadRevenue() {
      try {
        const earnings = collection(firestore(), "earnings");
        const weekAgo = Timestamp.fromMillis(Date.now() - 7 * 24 * 60 * 60 * 1000);
        const recent = query(earnings, where("createdAt", ">=", weekAgo));

        const [week, all, latest] = await Promise.all([
          getAggregateFromServer(recent, {
            commission: sum("commission"),
            gross: sum("grossFare"),
          }),
          getAggregateFromServer(earnings, { commission: sum("commission") }),
          getDocs(query(earnings, orderBy("createdAt", "desc"), limit(1))),
        ]);

        setRevenue({
          commission7d: week.data().commission,
          gross7d: week.data().gross,
          commissionAll: all.data().commission,
          // Currency lives on the ledger entries, not in code.
          currency:
            (latest.docs[0]?.data().currency as string | undefined) ?? "GBP",
        });
      } catch (e) {
        setError(`Failed to load revenue: ${String(e)}`);
      }
    }

    load();
    loadRevenue();
  }, []);

  if (error) return <p className="text-red-600">{error}</p>;
  if (!stats) return <p className="text-slate-500">Loading…</p>;

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
      <h2 className="text-lg font-semibold">Revenue</h2>
      <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-3">
        <div className="rounded-2xl bg-blue-600 p-5 text-white shadow-sm">
          <p className="text-sm text-blue-100">Your commission — last 7 days</p>
          <p className="mt-1 text-3xl font-semibold">
            {revenue ? money(revenue.commission7d, revenue.currency) : "…"}
          </p>
        </div>
        <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
          <p className="text-sm text-slate-500">Commission — all time</p>
          <p className="mt-1 text-3xl font-semibold">
            {revenue ? money(revenue.commissionAll, revenue.currency) : "…"}
          </p>
        </div>
        <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
          <p className="text-sm text-slate-500">Fares processed — last 7 days</p>
          <p className="mt-1 text-3xl font-semibold">
            {revenue ? money(revenue.gross7d, revenue.currency) : "…"}
          </p>
        </div>
      </div>

      <h2 className="mt-8 text-lg font-semibold">Overview</h2>
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
