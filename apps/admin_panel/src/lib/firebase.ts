import { getApps, initializeApp, type FirebaseApp } from "firebase/app";
import { connectAuthEmulator, getAuth, type Auth } from "firebase/auth";
import {
  connectFirestoreEmulator,
  getFirestore,
  type Firestore,
} from "firebase/firestore";
import {
  connectFunctionsEmulator,
  getFunctions,
  httpsCallable,
  type Functions,
} from "firebase/functions";

// Point the whole app at `firebase emulators:start` instead of a real project.
// Lets you run and demo the panel with no Firebase project and no billing.
const USE_EMULATOR = process.env.NEXT_PUBLIC_USE_EMULATOR === "true";

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

// connect*Emulator throws if called twice on the same instance, so each getter
// wires its emulator exactly once.
let authWired = false;
let firestoreWired = false;
let functionsWired = false;

export function firebaseAuth(): Auth {
  const auth = getAuth(app());
  if (USE_EMULATOR && !authWired) {
    authWired = true;
    connectAuthEmulator(auth, "http://127.0.0.1:9099", { disableWarnings: true });
  }
  return auth;
}

export function firestore(): Firestore {
  const db = getFirestore(app());
  if (USE_EMULATOR && !firestoreWired) {
    firestoreWired = true;
    connectFirestoreEmulator(db, "127.0.0.1", 8080);
  }
  return db;
}

function fns(): Functions {
  const functions = getFunctions(
    app(),
    process.env.NEXT_PUBLIC_FIREBASE_FUNCTIONS_REGION ?? "europe-west2"
  );
  if (USE_EMULATOR && !functionsWired) {
    functionsWired = true;
    connectFunctionsEmulator(functions, "127.0.0.1", 5001);
  }
  return functions;
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
