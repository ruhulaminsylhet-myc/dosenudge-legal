# Taxi Platform — Driver App · Rider App · Admin Panel · Firebase Backend

A complete three-tier ride-hailing MVP:

| Tier | Tech | Path |
|---|---|---|
| Driver app | Flutter + Firebase | `apps/driver_app/` |
| Rider app | Flutter + Firebase | `apps/rider_app/` |
| Admin panel | Next.js 15 + TypeScript + Tailwind | `apps/admin_panel/` |
| Server | Cloud Functions (TS) + Firestore + FCM | `functions/`, `firestore.rules` |

> `index.html` at the repo root is the unrelated DoseNudge privacy policy
> (kept for GitHub Pages) — not part of this platform.

## What the platform does

- **Riders** register, get a fare estimate, request a taxi, track status live,
  rate the driver afterwards, and see their history.
- **Drivers** apply with vehicle details, upload verification documents
  (licence, insurance, vehicle photo), wait for admin approval, go online
  (live GPS + geohash), receive nearby ride offers via push, accept atomically,
  drive the trip through `accepted → arrived → in_progress → completed`, and see earnings.
  The trip is metered by GPS, so the fare reflects the route actually driven.
- **Admin (you)** reviews driver documents before approving/rejecting,
  suspends/reactivates any user (kills their session everywhere), watches live
  rides, and edits pricing, commission %, and dispatch settings — all changes
  take effect immediately.
- **Server** matches each request to the nearest online approved drivers
  (geohash radius query), computes fares from `config/pricing`, settles
  completed trips into an earnings ledger, sends all push notifications, and
  expires unanswered requests.
- **Payments (Stripe Connect)** — drivers onboard for payouts in-app; riders pay
  by card on Stripe Checkout after the trip. Your commission is taken
  automatically as an application fee and the rest lands in the driver's
  account, so there is no payout run to manage. Cash still works: if a driver
  hasn't finished payout setup, the rider is told to settle in cash.

Both apps ship in **English and Bangla**, following the device language.

Security: role-based access via Firebase custom claims (`role`, `admin`) +
Firestore rules. Clients can never grant themselves a role, change approval
status, or write earnings. See `docs/ARCHITECTURE.md`.

## Setup (one-time, ~30 minutes)

### 1. Firebase project

1. Create a project at <https://console.firebase.google.com> — **enable the
   Blaze plan** (required for Cloud Functions; free tier allowances still apply).
2. Enable **Authentication → Email/Password**, **Firestore**, **Storage**, **Cloud Messaging**.
3. Put your project id in `.firebaserc`.

### 2. Deploy the backend

```bash
npm install -g firebase-tools
firebase login
cd functions && npm install && cd ..
firebase deploy --only firestore,storage,functions
```

### 3. Bootstrap the first admin and pricing

```bash
# Create your own account first via the admin panel login page… it will fail
# with "no admin access" — that's expected. Or create the user in
# Firebase Console → Authentication → Add user.
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccountKey.json
node scripts/set-admin.mjs you@example.com
node scripts/seed-pricing.mjs GBP     # or BDT for a Bangladesh launch
```

Further admins can be granted from code via the `adminGrantAdmin` callable.
Pricing, commission % and dispatch settings are editable from the admin panel
afterwards — nothing is hardcoded in the apps.

### 4. Payments (optional for a cash-only launch)

Create a Stripe account, enable **Connect**, then:

```bash
firebase functions:secrets:set STRIPE_SECRET_KEY      # sk_live_… or sk_test_…
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET  # whsec_… (step 3 below)
```

1. Add `PUBLIC_RETURN_URL=https://yourdomain.com` to `functions/.env` — where
   Stripe sends drivers and riders back after onboarding/checkout.
2. Deploy: `firebase deploy --only functions`.
3. In the Stripe dashboard → Developers → Webhooks, add the deployed
   `stripeWebhook` URL and subscribe to `checkout.session.completed`,
   `checkout.session.async_payment_failed`, `checkout.session.expired` and
   `account.updated`. Copy the signing secret into the secret above and
   redeploy.

Test it with Stripe's test keys and card `4242 4242 4242 4242` before going
live. Commission comes from `config/pricing.commissionPct` — the same number the
earnings ledger uses.

### 5. Admin panel

```bash
cd apps/admin_panel
cp .env.example .env.local   # fill in Firebase web-app config
npm install
npm run dev                  # http://localhost:3000
```

Deploy to Vercel: import the repo, set root directory to `apps/admin_panel`,
add the same env vars. Cost: £0 on the hobby tier.

### 6. Flutter apps

One script generates the `android/` and `ios/` folders for both apps and
patches in everything they need — location, background-location and
notification permissions, the photo-library usage string for document uploads,
and the `minSdk 23` the Firebase SDKs require. Safe to re-run.

```bash
node scripts/setup-flutter-apps.mjs
```

Then point each app at your Firebase project:

```bash
dart pub global activate flutterfire_cli
cd apps/driver_app && flutterfire configure && flutter run
cd ../rider_app   && flutterfire configure && flutter run
```

Give the two apps **different bundle ids** (e.g. `com.yourco.taxi.driver` and
`com.yourco.taxi.rider`) inside the *same* Firebase project. `flutterfire`
writes `lib/firebase_options.dart`, which is gitignored because it differs per
environment.

## Try it with no Firebase project (emulator demo)

Run the whole admin panel against the local emulator — no project, no billing,
no credentials:

```bash
npm install                      # once, for the operator scripts
npm run emulators                # terminal 1: auth + firestore
npm run seed-emulator            # terminal 2: demo admin, drivers, rides
cd apps/admin_panel && npm install
NEXT_PUBLIC_USE_EMULATOR=true npm run dev
```

Sign in at <http://localhost:3000> with **admin@demo.test / demo1234**. You get
3 drivers (one pending approval with documents to review), 5 rides across every
status, and GBP pricing — enough to click through the whole operator flow before
touching a real project.

## Tests

Security rules are the main thing standing between a driver and someone else's
data, so they have their own suite (39 assertions) that runs against the
Firestore emulator — no project or credentials needed:

```bash
npm install -g firebase-tools
cd tests && npm install && npm test
```

It covers who may read driver profiles and open ride requests, every legal and
illegal ride-status transition, which fields a client may write on a ride, the
earnings ledger being server-only, self-promotion to admin, and drivers
enabling their own Stripe payouts. CI runs it on every push.

## Monthly cost estimate (MVP scale, ~1k rides/month)

| Service | Cost |
|---|---|
| Firestore + Functions + FCM (Blaze free allowances) | ~£0–5 |
| Vercel hobby (admin panel) | £0 |
| Google Maps API | £0 — MVP deep-links to the Maps app instead |
| Stripe | no monthly fee; 1.5% + 20p per UK card charge, taken from the fare |
| **Total** | **≈ £0–5/month** + Stripe's per-transaction cut |

## Roadmap (deliberately not in MVP)

1. Saved cards + automatic charge on trip end (today the rider taps to pay on
   Stripe Checkout).
2. In-app live map (`google_maps_flutter`) + driver ETA.
3. Driver-rates-rider (rider-rates-driver already ships) and automated
   document expiry reminders.
4. bKash / Nagad for a Bangladesh launch (Stripe covers UK cards today).
