"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";

export default function Home() {
  const { user, isAdmin, loading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (loading) return;
    router.replace(user && isAdmin ? "/dashboard" : "/login");
  }, [user, isAdmin, loading, router]);

  return (
    <main className="flex min-h-screen items-center justify-center text-slate-500">
      Loading…
    </main>
  );
}
