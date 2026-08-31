import { getApps, initializeApp, type FirebaseApp } from "firebase/app";
import { getAuth, type Auth } from "firebase/auth";
import { getFirestore, type Firestore } from "firebase/firestore";
import { getFunctions, httpsCallable } from "firebase/functions";

// Lazy singletons: nothing initializes at module scope, so Next.js can
// prerender pages without real Firebase env vars.
function app(): FirebaseApp {
  return (
    getApps()[0] ??
    initializeApp({
      apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
      authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
      projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
      storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
      messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
      appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
    })
  );
}

export function firebaseAuth(): Auth {
  return getAuth(app());
}

export function firestore(): Firestore {
  return getFirestore(app());
}

function fns() {
  return getFunctions(
    app(),
    process.env.NEXT_PUBLIC_FIREBASE_FUNCTIONS_REGION ?? "europe-west2"
  );
}

export function callSetDriverApproval(data: {
  driverId: string;
  approvalStatus: "approved" | "rejected" | "pending";
}) {
  return httpsCallable<typeof data, { ok: boolean }>(
    fns(),
    "adminSetDriverApproval"
  )(data);
}

export function callSetUserStatus(data: {
  userId: string;
  status: "active" | "suspended";
}) {
  return httpsCallable<typeof data, { ok: boolean }>(
    fns(),
    "adminSetUserStatus"
  )(data);
}

export function callGrantAdmin(data: { userId: string; admin: boolean }) {
  return httpsCallable<typeof data, { ok: boolean }>(fns(), "adminGrantAdmin")(
    data
  );
}
