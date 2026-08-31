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

## 6. Admin panel

Next.js client app — Firebase JS SDK দিয়ে সরাসরি Firestore পড়ে (admin claim
rules এ check হয়), আর privileged action গুলোতে callable functions ডাকে
(`adminSetDriverApproval`, `adminSetUserStatus`, `adminGrantAdmin`)। ফলে server
key Vercel এ রাখতে হয় না — attack surface ছোট।

Pages: Dashboard (aggregate counts), Drivers (approve/reject + live online
status), Users (search + suspend/reactivate), Rides (live `onSnapshot` feed),
Pricing (config editor)।

## 7. কেন এই decisions (trade-offs)

| Decision | কারণ |
|---|---|
| Maps API বাদ, Google Maps deep-link | £0 cost, zero API-key friction; পরে drop-in upgrade |
| Native geocoding (`geocoding` pkg) | Address→latlng free, on-device |
| Callable functions, REST API না | Auth+claims built-in, CORS/token plumbing নেই |
| Firestore rules এ status machine | Function round-trip ছাড়াই instant, offline-safe transitions |
| Cash payment MVP | Stripe Connect onboarding একটা আলাদা মাইলফলক — আগে liquidity প্রমাণ করো |
