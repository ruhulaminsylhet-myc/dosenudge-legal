"use client";

import { useEffect, useState } from "react";
import { collection, onSnapshot, orderBy, query } from "firebase/firestore";
import { callSetUserStatus, firestore } from "@/lib/firebase";
import type { UserDoc } from "@/lib/types";
import { StatusBadge } from "@/components/StatusBadge";

export default function UsersPage() {
  const [users, setUsers] = useState<UserDoc[]>([]);
  const [search, setSearch] = useState("");
  const [busyId, setBusyId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const q = query(collection(firestore(), "users"), orderBy("createdAt", "desc"));
    return onSnapshot(
      q,
      (snap) =>
        setUsers(
          snap.docs.map((d) => ({ id: d.id, ...(d.data() as Omit<UserDoc, "id">) }))
        ),
      (e) => setError(String(e))
    );
  }, []);

  async function toggleStatus(u: UserDoc) {
    const status = u.status === "active" ? "suspended" : "active";
    if (
      status === "suspended" &&
      !confirm(`Suspend ${u.name}? They will be signed out everywhere.`)
    ) {
      return;
    }
    setBusyId(u.id);
    setError(null);
    try {
      await callSetUserStatus({ userId: u.id, status });
    } catch (e) {
      setError(`Action failed: ${String(e)}`);
    } finally {
      setBusyId(null);
    }
  }

  const term = search.trim().toLowerCase();
  const visible = term
    ? users.filter(
        (u) =>
          u.name?.toLowerCase().includes(term) ||
          u.email?.toLowerCase().includes(term) ||
          u.phone?.includes(term)
      )
    : users;

  return (
    <div>
      <div className="flex items-center justify-between gap-4">
        <h2 className="text-lg font-semibold">Users</h2>
        <input
          placeholder="Search name, email, phone…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-72 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm outline-none focus:border-blue-500"
        />
      </div>

      {error && <p className="mt-3 text-sm text-red-600">{error}</p>}

      <div className="mt-4 overflow-x-auto rounded-2xl border border-slate-200 bg-white shadow-sm">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">Name</th>
              <th className="px-4 py-3">Contact</th>
              <th className="px-4 py-3">Role</th>
              <th className="px-4 py-3">Status</th>
              <th className="px-4 py-3">Joined</th>
              <th className="px-4 py-3">Actions</th>
            </tr>
          </thead>
          <tbody>
            {visible.map((u) => (
              <tr key={u.id} className="border-b border-slate-100 last:border-0">
                <td className="px-4 py-3 font-medium">{u.name}</td>
                <td className="px-4 py-3">
                  <p>{u.email}</p>
                  <p className="text-xs text-slate-500">{u.phone}</p>
                </td>
                <td className="px-4 py-3 capitalize">{u.role}</td>
                <td className="px-4 py-3">
                  <StatusBadge value={u.status} />
                </td>
                <td className="px-4 py-3 text-slate-500">
                  {u.createdAt?.toDate().toLocaleDateString() ?? "—"}
                </td>
                <td className="px-4 py-3">
                  {u.role !== "admin" && (
                    <button
                      disabled={busyId === u.id}
                      onClick={() => toggleStatus(u)}
                      className={`rounded-lg px-3 py-1.5 text-xs font-medium text-white disabled:opacity-50 ${
                        u.status === "active"
                          ? "bg-red-600 hover:bg-red-700"
                          : "bg-emerald-600 hover:bg-emerald-700"
                      }`}
                    >
                      {u.status === "active" ? "Suspend" : "Reactivate"}
                    </button>
                  )}
                </td>
              </tr>
            ))}
            {visible.length === 0 && (
              <tr>
                <td colSpan={6} className="px-4 py-8 text-center text-slate-500">
                  No users found.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
