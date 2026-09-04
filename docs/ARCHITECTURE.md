# Architecture — Taxi Platform

এই document টা পুরো system এর ভেতরের কাজ ব্যাখ্যা করে — data model, ride lifecycle,
security (RBAC), আর dispatch engine কীভাবে কাজ করে। Code সব English এ, ব্যাখ্যা
Bangla + English mix এ।

## 1. High-level flow

```
Rider App ──create──▶ rides/{id} (status: requested)
                          │ Firestore trigger
                          ▼
              onRideCreated (Cloud Function)
              · fare estimate লিখে দেয়
              · geohash query দিয়ে কাছের online approved drivers খুঁজে
              · তাদের FCM push পাঠায়
                          │
Driver App ──accept──▶ status: accepted  (transaction — একজনই পাবে)
Driver App ──────────▶ arrived → in_progress → completed
                          │ Firestore trigger
                          ▼
              onRideUpdated (Cloud Function)
              · প্রতি step এ rider কে push notification
              · completed হলে: final fare, commission কেটে
                earnings ledger entry + driver totals update
```

## 2. Data model (Firestore)

| Collection | Purpose | কে লিখতে পারে |
|---|---|---|
| `users/{uid}` | সব user এর profile + role (`rider`/`driver`/`admin`) + status | নিজে (role/status বাদে), admin |
| `drivers/{uid}` | Driver application: vehicle, approvalStatus, isOnline, location+geohash, rating, totals | Driver নিজে (approval/rating/totals বাদে), admin |
| `rides/{id}` | পুরো ride lifecycle | Rider (create/cancel), driver (claim/progress), admin |
| `earnings/{id}` | Settlement ledger — trip-by-trip payout record | **শুধু Cloud Functions** |
| `config/pricing` | Fare rates, commission %, dispatch settings | শুধু admin |

Ride statuses: `requested → accepted → arrived → in_progress → completed`,
plus `cancelled` (rider/driver/admin/system) আর `expired` (timeout এ কেউ নেয়নি)।

## 3. Security model (RBAC) — সবচেয়ে গুরুত্বপূর্ণ অংশ

**তিন স্তরের defence:**

1. **Custom claims** — `role: driver|rider` set হয় server-side এ
   (`onUserCreated` trigger), আর `admin: true` শুধু bootstrap script বা
   অন্য admin এর `adminGrantAdmin` call দিয়ে। Client কখনো নিজের claim
   লিখতে পারে না।
2. **Firestore rules** — প্রতিটা sensitive field level এ enforce করা:
   - driver নিজের `approvalStatus`, `rating`, `totalEarnings` change করতে পারে না
   - ride এর status transition গুলো rules এ hard-coded (যেমন `accepted`
     থেকে শুধু `arrived`/`cancelled` এ যাওয়া যায়)
   - ride claim atomic: `driverId == null && status == 'requested'` হলেই কেবল নেওয়া যায়
   - `earnings` client-side write সম্পূর্ণ বন্ধ
3. **Cloud Functions (Admin SDK)** — privileged operations (approve, suspend,
   settle) শুধু এখান দিয়েই হয়। Suspend করলে Firebase Auth account **disable**
   + refresh token revoke হয়, তাই user সব device থেকে সাথে সাথে bad হয়ে যায়।

**Data minimisation (UK GDPR):** কেউ প্রয়োজনের বেশি data পড়তে পারে না —
- `drivers` collection-এ driver-এর phone আর live location আছে, তাই সেটা শুধু
  **নিজে + admin** পড়তে পারে। Rider-কে যা দেখাতে হয় (নাম, গাড়ি, rating) সেটা
  accept-এর সময় function ride doc-এর `driverInfo` field-এ copy করে দেয়।
- একটা open ride request শুধু **যে driver দের offer করা হয়েছে** (`offeredTo`
  array) তারাই পড়তে ও accept করতে পারে। তাই London-এর driver Manchester-এর
  rider-এর address কখনো দেখবে না — rules আর app query দুই জায়গাতেই enforce করা।

## 4. Dispatch engine (driver matching)

- Driver online হলে app প্রতি ~25 metre এ `drivers/{uid}` doc এ
  `GeoPoint` + **geohash** লেখে (Dart এ ছোট geohash encoder আছে —
  `apps/driver_app/lib/core/geohash.dart` — এটা `geofire-common` এর
  encoding এর সাথে compatible)।
- `onRideCreated` function `geofire-common` এর `geohashQueryBounds` দিয়ে
  pickup point এর চারপাশে radius query চালায় (default 8 km,
  `config/pricing.searchRadiusKm` থেকে আসে), distance sort করে nearest
  N (default 10) driver কে FCM push পাঠায়।
- Driver দের in-app live list ও আছে (`status == 'requested'` stream), তাই
  push miss হলেও request দেখা যায়।
- ২ মিনিটে (configurable) কেউ না নিলে scheduled function `expired` করে দেয়।

**Scaling note:** এক city-scale MVP তে এটা যথেষ্ট। বড় scale এ পরে driver
location কে আলাদা `driver_locations` collection বা Redis geo-index এ সরানো যাবে —
write hot-spot আলাদা হয়ে যায়, `drivers` doc টা তখন profile-only থাকে।

## 5. Fare & settlement

সব rates `config/pricing` এ (admin panel → Pricing) — **কোনো currency বা rate
code এ hardcode নেই**, তাই UK (GBP) বা BD (BDT) দুটোই শুধু config change:

```
total = max(baseFare + perKm·distance + perMin·duration, minimumFare)
commission = total × commissionPct%          → platform এর আয়
driverPayout = total − commission            → earnings ledger এ জমা হয়
```

MVP তে distance টা estimate (haversine × 1.3 road factor), duration টা আসল
(trip start → complete)। Settlement একটা Firestore **transaction** এ হয়:
ride এ finalFare + driver totals increment + ledger entry — সব একসাথে, কখনো
আধা-হওয়া state থাকবে না।

## 6. Ratings ও driver documents

**Rating:** trip complete হওয়ার পর rider app-এ star rating card আসে। কিন্তু rating
সরাসরি Firestore-এ লেখা হয় **না** — rules-এ `drivers.rating` client-write বন্ধ।
Rider `rateRide` callable ডাকে, সেটা একটা transaction-এ:
1. check করে ride টা এই rider-এরই, `completed`, আর আগে rate করা হয়নি
2. stored `rating × ratingCount` থেকে নতুন average বের করে (client যা পাঠাল
   তা বিশ্বাস না করে) — দুইজন একসাথে rate করলেও value drift করবে না

**Documents:** driver approval-এর আগে licence, insurance আর vehicle photo upload
করতে হয় → Firebase Storage-এ `driver_docs/{uid}/` path-এ (storage rules: শুধু
নিজে + admin পড়তে পারে, ১০ MB limit, image/PDF only)। URL গুলো driver doc-এর
`documents` map-এ জমা হয়, আর admin panel-এর Drivers table-এ clickable link
হিসেবে দেখায় — approve চাপার আগে admin যাচাই করে নিতে পারে।

## 7. Payments (Stripe Connect)

**কেন Connect:** টাকা rider → Stripe → driver-এর নিজের account-এ যায়, তোমার
commission মাঝখানে `application_fee_amount` হিসেবে কেটে যায়। তাই তোমাকে আলাদা
করে driver-দের টাকা পাঠাতে হয় না, আর তোমার account-এ কারো টাকা জমা থাকে না
(regulatory ঝামেলা অনেক কম)।

```
Driver → createDriverPayoutAccount → Stripe Express onboarding (browser)
                                         │ account.updated webhook
                                         ▼
                              drivers/{uid}.payoutsEnabled = true

Rider (trip শেষে) → createRideCheckout → Stripe Checkout page
                                         │ checkout.session.completed webhook
                                         ▼
                              rides/{id}.payment.status = 'paid'
                              commission → তোমার account
                              বাকিটা → driver-এর account
```

**দুটো গুরুত্বপূর্ণ rule:**
1. `payment.status` **শুধু signature-verified webhook** থেকে set হয় — rider
   success URL-এ ফিরে এলো মানে টাকা এসেছে, এমন ধরা হয় না।
2. `drivers.payoutsEnabled` আর `stripeAccountId` client লিখতে পারে না (rules-এ
   blocked, test করা) — নইলে driver নিজে flag on করে card payment নিতে পারত
   অথচ Stripe তাকে verify-ই করেনি।

Driver payout setup না করলে checkout fail করে আর rider-কে cash দিতে বলা হয় —
MVP-তে এটাই intended behaviour।

## 8. Admin panel

Next.js client app — Firebase JS SDK দিয়ে সরাসরি Firestore পড়ে (admin claim
rules এ check হয়), আর privileged action গুলোতে callable functions ডাকে
(`adminSetDriverApproval`, `adminSetUserStatus`, `adminGrantAdmin`)। ফলে server
key Vercel এ রাখতে হয় না — attack surface ছোট।

Pages: Dashboard (aggregate counts), Drivers (approve/reject + live online
status), Users (search + suspend/reactivate), Rides (live `onSnapshot` feed),
Pricing (config editor)।

## 9. কেন এই decisions (trade-offs)

| Decision | কারণ |
|---|---|
| Maps API বাদ, Google Maps deep-link | £0 cost, zero API-key friction; পরে drop-in upgrade |
| Native geocoding (`geocoding` pkg) | Address→latlng free, on-device |
| Callable functions, REST API না | Auth+claims built-in, CORS/token plumbing নেই |
| Firestore rules এ status machine | Function round-trip ছাড়াই instant, offline-safe transitions |
| Stripe Checkout, in-app SDK না | flutter_stripe-এর platform config ছাড়াই কাজ করে; hosted page = কম PCI scope |
| Destination charge (application fee) | Driver payout automatic, তোমার account-এ কারো টাকা জমা থাকে না |
