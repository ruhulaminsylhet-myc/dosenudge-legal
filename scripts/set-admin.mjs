#!/usr/bin/env node
// Bootstrap the FIRST admin account. After that, grant/revoke admins from the
// admin panel (which calls the adminGrantAdmin function).
//
// Usage:
//   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccountKey.json
//   node scripts/set-admin.mjs you@example.com
//
// The service account key comes from Firebase Console → Project settings →
// Service accounts → Generate new private key. NEVER commit that file.

import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

const email = process.argv[2];
if (!email) {
  console.error("Usage: node scripts/set-admin.mjs <email>");
  process.exit(1);
}

initializeApp({ credential: applicationDefault() });

const auth = getAuth();
const user = await auth.getUserByEmail(email);
await auth.setCustomUserClaims(user.uid, {
  ...(user.customClaims ?? {}),
  admin: true,
});
await auth.revokeRefreshTokens(user.uid);

const userRef = getFirestore().doc(`users/${user.uid}`);
const snap = await userRef.get();
if (!snap.exists) {
  await userRef.set({
    role: "admin",
    status: "active",
    name: user.displayName ?? email,
    email,
    phone: user.phoneNumber ?? "",
    createdAt: FieldValue.serverTimestamp(),
  });
}

console.log(`✔ ${email} (${user.uid}) is now an admin. They must sign in again.`);
