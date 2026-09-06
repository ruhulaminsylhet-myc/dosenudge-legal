"use client";

import { useEffect, useState, type FormEvent } from "react";
import { doc, getDoc, setDoc } from "firebase/firestore";
import { firestore } from "@/lib/firebase";
import type { PricingConfig } from "@/lib/types";

const DEFAULTS: PricingConfig = {
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

const FIELDS: {
  key: keyof PricingConfig;
  label: string;
  step?: string;
  type: "text" | "number";
}[] = [
  { key: "currency", label: "Currency (ISO 4217)", type: "text" },
  { key: "baseFare", label: "Base fare", step: "0.01", type: "number" },
  { key: "perKm", label: "Per km", step: "0.01", type: "number" },
  { key: "perMin", label: "Per minute", step: "0.01", type: "number" },
  { key: "minimumFare", label: "Minimum fare", step: "0.01", type: "number" },
  { key: "commissionPct", label: "Platform commission %", step: "0.5", type: "number" },
  { key: "searchRadiusKm", label: "Driver search radius (km)", step: "1", type: "number" },
  { key: "maxDriversNotified", label: "Max drivers notified", step: "1", type: "number" },
  { key: "requestTimeoutSec", label: "Request timeout (sec)", step: "10", type: "number" },
  { key: "cancellationFee", label: "Late cancellation fee (0 = off)", step: "0.01", type: "number" },
  { key: "freeCancellationSec", label: "Free cancellation window (sec)", step: "10", type: "number" },
  { key: "maxRouteFactor", label: "Max billable route factor", step: "0.1", type: "number" },
];

export default function PricingPage() {
  const [config, setConfig] = useState<PricingConfig | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    getDoc(doc(firestore(), "config", "pricing"))
      .then((snap) =>
        setConfig({ ...DEFAULTS, ...(snap.data() as Partial<PricingConfig>) })
      )
      .catch((e) => setMessage(`Failed to load: ${String(e)}`));
  }, []);

  async function save(e: FormEvent) {
    e.preventDefault();
    if (!config) return;
    setBusy(true);
    setMessage(null);
    try {
      await setDoc(doc(firestore(), "config", "pricing"), config);
      setMessage("Saved. New rides use this pricing immediately.");
    } catch (err) {
      setMessage(`Save failed: ${String(err)}`);
    } finally {
      setBusy(false);
    }
  }

  if (!config) return <p className="text-slate-500">Loading pricing…</p>;

  return (
    <div className="max-w-xl">
      <h2 className="text-lg font-semibold">Pricing & dispatch</h2>
      <p className="mt-1 text-sm text-slate-500">
        Stored in <code>config/pricing</code>; Cloud Functions read this on every
        fare calculation.
      </p>

      <form
        onSubmit={save}
        className="mt-4 grid grid-cols-1 gap-4 rounded-2xl border border-slate-200 bg-white p-6 shadow-sm sm:grid-cols-2"
      >
        {FIELDS.map((f) => (
          <label key={f.key} className="block text-sm font-medium">
            {f.label}
            <input
              type={f.type}
              step={f.step}
              required
              value={config[f.key]}
              onChange={(e) =>
                setConfig({
                  ...config,
                  [f.key]:
                    f.type === "number" ? Number(e.target.value) : e.target.value.toUpperCase(),
                })
              }
              className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-blue-500"
            />
          </label>
        ))}
        <div className="sm:col-span-2">
          <button
            type="submit"
            disabled={busy}
            className="rounded-lg bg-blue-600 px-4 py-2.5 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
          >
            {busy ? "Saving…" : "Save pricing"}
          </button>
          {message && <p className="mt-3 text-sm text-slate-600">{message}</p>}
        </div>
      </form>
    </div>
  );
}
