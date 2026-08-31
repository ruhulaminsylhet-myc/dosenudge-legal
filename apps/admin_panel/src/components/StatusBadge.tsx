const COLORS: Record<string, string> = {
  active: "bg-emerald-100 text-emerald-700",
  approved: "bg-emerald-100 text-emerald-700",
  completed: "bg-emerald-100 text-emerald-700",
  online: "bg-emerald-100 text-emerald-700",
  pending: "bg-amber-100 text-amber-700",
  requested: "bg-amber-100 text-amber-700",
  accepted: "bg-blue-100 text-blue-700",
  arrived: "bg-blue-100 text-blue-700",
  in_progress: "bg-blue-100 text-blue-700",
  suspended: "bg-red-100 text-red-700",
  rejected: "bg-red-100 text-red-700",
  cancelled: "bg-red-100 text-red-700",
  expired: "bg-slate-100 text-slate-600",
  offline: "bg-slate-100 text-slate-600",
};

export function StatusBadge({ value }: { value: string }) {
  return (
    <span
      className={`inline-block rounded-full px-2.5 py-0.5 text-xs font-medium ${
        COLORS[value] ?? "bg-slate-100 text-slate-600"
      }`}
    >
      {value.replace("_", " ")}
    </span>
  );
}
