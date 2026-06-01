# NEXUS ARENA — Handoff Document
**Last updated:** 2026-06-01  
**Status:** Phase 10 complete. Phase 11 (Testing + Bug Fixes) is next.

> ⚠️ **ACTION REQUIRED before payments work** — see "Phase 6 setup checklist" below.
> You must set 3 env vars in InsForge, register the webhook in Razorpay, and pass
> `--dart-define=RAZORPAY_KEY_ID=...` when running the app.

> 🔒 **SECURITY FIX shipped in Phase 7** — users could previously self-approve KYC by
> PATCHing `profiles.kyc_status`. Locked via column-level grants (migration `...0003`).
> See "Phase 7" → security note. No action needed; flagged for awareness.

---

## Project Overview

Real-money esports tournament app for Free Fire players in India.  
Backend: InsForge (PostgreSQL + Edge Functions) | Frontend: Flutter | Payments: Razorpay (pending)

**InsForge project:** `b6b4053f-ebf3-4b55-a116-6bd84e233c11`  
**App URL:** `https://xymp52ea.ap-southeast.insforge.app`  
**Functions URL:** `https://xymp52ea.functions.insforge.app`

---

## Completed Phases

### Phase 1 — Schema + Models + Service Layer ✓

**DB migrations applied (live):**
- `20260531*` — Initial 6 migrations (profiles, wallets, wallet_transactions, tournaments, matches, match_results, withdrawals, otp_codes, enums)
- `20260601000001_update-tournament-schema.sql` — Dropped `entry_fee_matches_mode` CHECK constraint; added columns: `tournament_type` (daily/weekly), `tier` (1/2), `prize_1st/2nd/3rd` (paise), `min_players`

**Flutter packages added:** shimmer, lottie, percent_indicator, intl, share_plus (^12.0.2), connectivity_plus, package_info_plus, flutter_local_notifications

**`api_client.dart` changes:**
- Added `'apikey': AppConstants.insforgeAnonKey` to every request header (PostgREST requires it)
- Added `getList(path)` → `List<dynamic>` (PostgREST returns arrays, original `get()` returned Map)
- Added `patch(path, body)` → `Map<String, dynamic>`

**`main.dart`:** Wrapped in `ProviderScope` for Riverpod.

**`theme.dart`:** Added gold (#FFD700), silver (#C0C0C0), bronze (#CD7F32), purple (#7B2FBE), textPrimary (#FFFFFF), textSecondary (#9E9E9E), shimmerBase (#1A1A2E), shimmerHighlight (#2A2A4E).

**9 Dart models created:**
- `features/tournaments/models/tournament.dart` — `Tournament` with `statusDisplay()` factory, paise→Rs getters, `isDaily/isWeekly/isFull`
- `features/tournaments/models/tournament_registration.dart`
- `features/matches/models/match.dart`
- `features/matches/models/match_lobby.dart` — `isRoomVisible`, `timeUntilVisible`, `timeUntilMatch` getters
- `features/matches/models/match_result.dart`
- `features/wallet/models/wallet.dart` — includes all stats columns (totalDeposited, totalWon, etc.)
- `features/wallet/models/wallet_transaction.dart` — `isCredit` checks sign of `amount`
- `features/wallet/models/withdrawal.dart`
- `features/profile/models/profile.dart` — `canEditProfile` (24h lock), `nextEditAllowedAt`

**4 service classes (static methods):** TournamentService, MatchService, WalletService, ProfileService

**3 Riverpod providers (manual AsyncNotifier, no codegen):**
- `tournamentsProvider` + `myRegistrationsProvider` + `joinedTournamentIdsProvider` (Set for O(1) lookup)
- `walletProvider`
- `authProvider`

**Router:** Added 9 routes — `/tournament/:id`, `/match-lobby/:id`, `/wallet`, `/add-money`, `/withdraw`, `/results`, `/profile`, `/kyc`, `/settings`. All new screens stubbed.

---

### Phase 2 — Home Screen ✓

**Files:**
- `features/home/screens/home_screen.dart` — `ConsumerWidget`, wallet balance in AppBar (shimmer while loading), TODAY'S TOURNAMENTS + WEEKLY SPECIAL sections (weekly shown Thu–Sun), pull-to-refresh (refreshes tournaments + wallet + registrations), shimmer skeleton (4 cards), empty state, error state + retry
- `features/tournaments/widgets/tournament_card.dart` — gradient banner fallback, mode badge (SOLO=green/DUO=purple/SQUAD=orange), tier badge, status badge, entry fee, prize pool, 🥇🥈🥉 breakdown (hidden if prizes=0), player progress bar (turns red when full), time label, JOIN button with 5 states
- `features/home/widgets/section_header.dart` — accent bar + "SUNDAY ONLY" tag for weekly section

**Bottom nav:** Home | Wallet | Results | Profile (4 tabs)

**DB test data:** 4 tournaments seeded (2 OPEN solo, 1 OPEN duo, 1 ONGOING squad)

---

### Phase 3 — Tournament Detail + Join Flow ✓

**Edge function deployed:** `join-tournament` at `https://xymp52ea.functions.insforge.app/join-tournament`
- Validates tournament (open, not full, not duplicate)
- Calls `deduct_wallet()` DB RPC atomically — PostgREST `/rest/v1/rpc/deduct_wallet`
- Inserts `tournament_registrations` row; rolls back via `credit_wallet()` on failure
- Returns `{ success, registration_id, match_id }` — match_id is non-null if admin has created the match

**Files:**
- `features/tournaments/screens/tournament_detail_screen.dart` — `ConsumerStatefulWidget`, seeds from cache for instant display, parallel fetch of tournament + match, SliverAppBar with gradient banner, entry fee (large green), `PrizeBreakdown` widget, player progress, HH:MM:SS countdown (self-disposing `_CountdownDisplay`), expandable rules, sticky JOIN button at bottom
- `features/tournaments/widgets/join_bottom_sheet.dart` — `ConsumerStatefulWidget`, balance before/after display (red if insufficient), team name field for DUO/SQUAD, error code → human message mapping, returns `bool` on dismiss
- `features/tournaments/widgets/prize_breakdown.dart` — gold/silver/bronze rows with TDS notice; graceful "to be announced" when prizes are 0

**JOIN button states:** OPEN → JOINED ✓ (or VIEW MATCH LOBBY) → FULL → LIVE → ENDED → low-balance warning

---

### Phase 4 — Match Lobby + Room ID System ✓

**Files:**
- `features/matches/screens/match_lobby_screen.dart` — `ConsumerStatefulWidget` + `SingleTickerProviderStateMixin`, 5 states: Loading / Locked (countdown to room open) / Room Open (pulsing green banner) / Live / Completed+Cancelled, auto-refresh every 30s via `Timer.periodic`, pull-to-refresh, share via `SharePlus.instance.share()`
- `features/matches/widgets/room_card.dart` — Room ID + Password display in large green text, copy-to-clipboard with 1-second snackbar confirmation per field
- `features/matches/widgets/lobby_countdown.dart` — HH:MM:SS block countdown (self-disposing), shows "Room is opening..." at zero

**`match_service.dart` addition:** `fetchMatchForTournament(tournamentId)` — queries `matches` with user JWT; RLS ensures only registered users get data; returns `Match?`

**Detail screen update:** Added `_matchId` state; `_load()` fetches tournament + match in parallel; if joined AND match exists → "VIEW MATCH LOBBY" button that navigates directly; after joining → auto-navigate to lobby if match found

**DB test data:** Match seeded for "Free Fire Solo Blitz" — Room ID `NX-7742`, Password `nexus2024`

---

### Phase 5 — Wallet Screen + Transaction History ✓

**Files:**
- `features/wallet/providers/transactions_provider.dart` — NEW. `TransactionsNotifier extends AsyncNotifier<TransactionsState>`. State holds `items` + `filterType` + `hasMore` + `loadingMore`. Methods: `setFilter(type)` (reloads page 0), `refresh()` (keeps filter), `loadMore()` (appends next 20, no-op if exhausted/loading; on error keeps existing items). `copyWith` uses a sentinel so `filterType` can be set back to null.
- `features/wallet/screens/wallet_screen.dart` — REPLACED stub. `ConsumerWidget`, `CustomScrollView` of slivers: balance card → stats row → "TRANSACTIONS" title → horizontal filter chips → transaction list. Pull-to-refresh refreshes wallet + transactions. Active filter read from `transactionsProvider` state (no local state). Empty/error/shimmer states for both balance card and list.
- `features/wallet/widgets/balance_card.dart` — gradient card, large green ₹ amount (Indian grouping via `NumberFormat.decimalPattern('en_IN')`), ADD MONEY (filled → `/add-money`) + WITHDRAW (outlined → `/withdraw`).
- `features/wallet/widgets/wallet_stats_row.dart` — 3 boxes: Total Added (accent), Total Won (gold), Withdrawn (textSecondary).
- `features/wallet/widgets/transaction_tile.dart` — type→(label,icon,color) via Dart 3 switch; `+₹` green credit / `-₹` red debit; date via `DateFormat('dd MMM yyyy, hh:mm a')`.

**Notes:** `wallet_transactions.amount` is positive for credit, negative for debit (`isCredit` getter). Stats live in `wallets` table (`total_deposited`, `total_won`, `total_withdrawn`). Pagination is a "LOAD MORE" button footer (not infinite scroll), 20/page. Filter tabs: All/Added(deposit)/Won(prize)/Entry Fee(entry_fee)/Withdrawn(withdrawal)/Refund(refund) — `tds` shows under All only. `flutter analyze`: 0 issues.

---

## Pending Phases

### Phase 6 — Razorpay Payment Integration ✓

**Package added:** `razorpay_flutter` (resolved to `1.4.5`).

**DB migration applied (live):** `20260601000002_create-razorpay-orders.sql` — `razorpay_orders`
(id, user_id, razorpay_order_id UNIQUE, razorpay_payment_id UNIQUE-nullable, receipt, amount_paise,
status `created|paid|failed`, created_at, updated_at). RLS: read-only `auth.uid() = user_id`;
writes only via service-role functions (matches project convention).

**Edge functions deployed (live):**
- `create-razorpay-order` — JWT → userId; validates amount (int, ₹50–₹10,000); `POST api.razorpay.com/v1/orders` with Basic auth (`btoa(keyId:keySecret)`); inserts pending `razorpay_orders` row; returns `{ order_id, amount(paise), currency, key_id }`.
- `verify-razorpay-payment` — verifies HMAC-SHA256 of `order_id|payment_id` (constant-time compare); confirms order ownership; **atomic claim** = conditional update `status created→paid WHERE status='created'` (this, not the unique index, is the idempotency guard); then `credit_wallet(userId, amount, 'deposit', order.id, 'razorpay', ...)`. Rolls status back to `created` if credit fails.
- `razorpay-webhook` — verifies `X-Razorpay-Signature` over the **raw body** using `RAZORPAY_WEBHOOK_SECRET`; on `payment.captured` runs the same created→paid claim + credit. Server-side safety net if the client never returns. Returns 5xx on credit failure so Razorpay retries; 200 (ignored) for other events.

**Flutter files:**
- `core/constants.dart` — added `razorpayKeyId = String.fromEnvironment('RAZORPAY_KEY_ID')`, `minTopUpRs=50`, `maxTopUpRs=10000`.
- `wallet/services/payment_service.dart` — `RazorpayOrder` model + `createOrder(amountRs)`, `verifyPayment(orderId, paymentId, signature)`.
- `wallet/widgets/amount_preset_chip.dart` — selectable ₹ chip.
- `wallet/screens/add_money_screen.dart` — REPLACED stub. `ConsumerStatefulWidget`; Razorpay instance created in `initState`, `clear()` in dispose; presets [50,100,200,500,1000] + custom field (digits only, 5 chars); custom field overrides preset; live validation; payment summary; sticky PAY button; processing overlay; success/failure dialogs. Success → refresh `walletProvider` + `transactionsProvider` → DONE pops to wallet. Phone prefill from `authProvider`. Shows a red banner if `RAZORPAY_KEY_ID` is empty.

**Android release-build fixes (were latent gaps):**
- `android/app/src/main/AndroidManifest.xml` — added `INTERNET` + `ACCESS_NETWORK_STATE` (Flutter only injects INTERNET into the *debug* manifest; release builds — for the whole app, not just Razorpay — need it in main).
- `android/app/proguard-rules.pro` — Razorpay keep rules; wired via `proguardFiles(...)` in the release block. Inert until `isMinifyEnabled = true` (Phase 12).

**`flutter analyze`: 0 issues.** Could not run the live payment flow — needs real Razorpay test keys (see checklist) and a device/emulator.

#### Phase 6 setup checklist (USER must do before payments function)
1. **Razorpay dashboard → Settings → API Keys** → generate **TEST** keys (`rzp_test_...` + secret).
2. **InsForge → Functions → Env/Secrets**, set:
   - `RAZORPAY_KEY_ID` = `rzp_test_xxx`
   - `RAZORPAY_KEY_SECRET` = `<secret>`
   - `RAZORPAY_WEBHOOK_SECRET` = `<a secret you choose>` (used in step 3)
   *(The functions read these via `Deno.env.get(...)`; until set they return `payment_not_configured` / `webhook_not_configured` 503.)*
3. **Razorpay dashboard → Settings → Webhooks** → add `https://xymp52ea.functions.insforge.app/razorpay-webhook`, event **`payment.captured`**, secret = the `RAZORPAY_WEBHOOK_SECRET` from step 2.
4. **Run the app** with the publishable key:
   `flutter run --dart-define=INSFORGE_ANON_KEY=<key> --dart-define=RAZORPAY_KEY_ID=rzp_test_xxx`
5. Test with a Razorpay test card; confirm wallet balance + a `deposit` row in transaction history, and `razorpay_orders.status = 'paid'`.

---

### Phase 7 — Withdrawal + KYC ✓

**Package added:** `image_picker` (resolved 1.1.x).

**🔒 SECURITY FIX (migration `20260601000003_lock-profile-columns.sql`, live):**
`anon`/`authenticated` previously held UPDATE on **all** `profiles` columns, so a user could
`PATCH /rest/v1/profiles { kyc_status: 'approved' }` and bypass the withdrawal KYC gate.
Fixed with column-level privileges: `REVOKE UPDATE ON profiles FROM anon, authenticated;
GRANT UPDATE (display_name, game_uid, upi_id, avatar_url) ... TO authenticated;`. `kyc_status`
is now service-role only. `updated_at` stays server-maintained by the `profiles_updated_at`
trigger; `ProfileService.updateProfile` only writes the 4 granted columns, so nothing broke.

**DB migration (live):** `20260601000004_create-kyc-submissions.sql` — `kyc_submissions`
(user_id, aadhaar_front/back, pan_card, selfie = storage keys, status `kyc_status`,
rejection_reason, submitted_at, reviewed_at). Read-only RLS `auth.uid() = user_id`; writes via service role.

**Storage:** private bucket **`kyc-documents`** created (isPublic=false). Upload via raw HTTP
`PUT /api/storage/buckets/kyc-documents/objects/{userId}/{docType}_{ts}.{ext}` with multipart
`file` field + `Authorization: Bearer <jwt>` + `apikey`. Keys namespaced under `{userId}/`.

**Existing DB trigger** `check_withdrawal_limits` (BEFORE INSERT on withdrawals) is authoritative:
raises `kyc_not_approved` if profile not approved, `daily_limit_exceeded` if today's non-failed/
rejected withdrawals + new > ₹10,000 (1,000,000 paise).

**Edge functions deployed (live):**
- `request-withdrawal` — validates amount (₹100–₹10,000 int) + UPI regex; pre-checks KYC approved + daily cap (nice errors); `deduct_wallet('withdrawal')`; inserts `withdrawals` (trigger re-validates atomically); **refunds via `credit_wallet('refund')` if the insert fails**. Returns `{ success, withdrawal_id }`.
- `submit-kyc` — validates 4 doc keys are non-empty and each starts with `{userId}/` (defense in depth); blocks if already approved; inserts `kyc_submissions`; sets `profiles.kyc_status='submitted'` (service role). User **cannot** self-approve.

**Flutter files:**
- `wallet/services/wallet_service.dart` — added `requestWithdrawal(amountRs, upiId)`.
- `wallet/providers/withdrawals_provider.dart` — `WithdrawalsNotifier` → `WithdrawalsState { items, todayWithdrawnPaise }` (fetches list + today's sum in parallel).
- `wallet/screens/withdraw_screen.dart` — REPLACED stub. Balance + today's remaining limit; **KYC gate banner** (pending/submitted/rejected variants → `/kyc`) replaces the form unless approved; amount field (min ₹100, max = min(balance, remaining daily)); UPI field (regex, prefilled from `profile.upiId`); submit → refresh wallet+withdrawals+transactions; past requests list with status badges + rejection reason.
- `kyc/services/kyc_service.dart` — `uploadDocument(userId, docType, file)` (multipart PUT → returns key), `submitKyc(...)`, `fetchLatestRejectionReason()`.
- `kyc/screens/kyc_screen.dart` — REPLACED stub. Status-driven: `approved`→verified, `submitted`→under-review, `rejected`→reason + resubmit, else→capture form. 4 doc slots (Aadhaar front/back, PAN, selfie); selfie forces front camera, docs offer camera/gallery; sequential upload with progress overlay → `submit-kyc` → refresh `authProvider` → "Submitted" dialog.

**iOS:** added `NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription` to `Info.plist` (image_picker hard-crashes on iOS without them). Android needs no manifest change (system intents).

**`flutter analyze`: 0 issues.** Couldn't run the live flow end-to-end: withdrawal needs a user with `kyc_status='approved'` (admin approval is Phase 10) and KYC capture needs a device camera.

**To test before Phase 10 admin exists:** approve a user manually —
`UPDATE profiles SET kyc_status='approved' WHERE id='<user-uuid>';` then the withdraw form unlocks.

---

### Phase 8 — Profile + Settings ✓

**Files created/replaced:**
- `profile/screens/profile_screen.dart` — `ConsumerWidget`; avatar circle (gradient initials); displayName + phone + game UID; KYC badge (pending/submitted/approved/rejected); `_StatsRow` (`StatefulWidget` → `ProfileService.fetchPlayerStats()` async, shows matches/wins/total-earned); menu sections (Account / Wallet / App) with ListTiles → /edit-profile, /kyc, /wallet, /withdraw, /settings; Sign Out with confirm dialog → `authProvider.signOut()` → `/phone`. Bottom nav tab 3 active.
- `profile/screens/edit_profile_screen.dart` — NEW; 24h lock banner shows `profile.nextEditAllowedAt` if locked; 3 text fields (Display Name, Free Fire UID, UPI ID) prefilled from profile; save → `ProfileService.updateProfile(...)` → `authProvider.refresh()` → pop. Button shows "PROFILE LOCKED" when locked.
- `settings/screens/settings_screen.dart` — App section (version via `PackageInfo.fromPlatform()` async, shown in `_VersionBadge` StatefulWidget); Legal (Privacy Policy / ToS / Refund Policy → snackbar placeholders); Support (email address); Sign Out with same confirm dialog.
- `results/screens/results_screen.dart` — `StatefulWidget`; calls `MatchService.fetchMyResults()` (RLS auto-filters to own results); pull-to-refresh; rank card (gold #1 / silver #2 / bronze #3 / grey else) with kills + points pills; net prize in green; TDS notice; empty + error states with retry.
- `core/router.dart` — Added `/edit-profile` → `EditProfileScreen`.

**Service additions:**
- `ProfileService.fetchPlayerStats()` → `PlayerStats({int matchesPlayed, int wins})` via `tournament_registrations?select=id` count + `match_results?rank=eq.1&select=id` count (both RLS-filtered, parallel Future.wait).
- `MatchService.fetchMyResults()` → `GET /rest/v1/match_results?order=created_at.desc` (RLS auto-filters by user via `tournament_registrations.user_id = auth.uid()` join).

**`flutter analyze`: 0 issues.**

---

### Phase 9 — FCM Push Notifications ✓

**Packages added:** `firebase_core: ^3.6.0`, `firebase_messaging: ^15.1.3` (`flutter_local_notifications` was already in pubspec from Phase 1).

**DB migration (live):** `20260601000005_create-device-tokens.sql` — `device_tokens` (user_id, token, platform `android|ios`). UNIQUE(user_id, token). Read-only RLS.

**Edge functions deployed (live):**
- `register-device-token` — upserts with `Prefer: resolution=ignore-duplicates`; validates platform enum.
- `send-notification` — **admin-only** (validates caller = service-role API key); fetches tokens from DB (all, or filtered by `user_ids[]`); gets FCM OAuth2 token via service-account JWT (RSA-SHA256 using `crypto.subtle`); loops through tokens calling FCM HTTP v1 API (`/v1/projects/{id}/messages:send`); returns `{sent, total}`. Reads `FIREBASE_SERVICE_ACCOUNT_JSON` env var.

**Android build config:**
- `settings.gradle.kts` — added `com.google.gms.google-services:4.4.2 apply false`.
- `app/build.gradle.kts` — applied `com.google.gms.google-services` plugin (reads `google-services.json`).
- `AndroidManifest.xml` — added `POST_NOTIFICATIONS` permission (required Android 13+/API 33+).

**Flutter files:**
- `main.dart` — `await Firebase.initializeApp()` before `runApp`; `@pragma('vm:entry-point')` background handler (just re-inits Firebase); `await initializeNotifications()` after `runApp` so GoRouter is ready for initial-message navigation.
- `notifications/services/notification_service.dart` — `initializeNotifications()`: creates Android notification channel `nexus_arena_high` (high importance); requests FCM permission; calls `registerToken()`; sets up `onTokenRefresh`, `onMessage` (foreground → local notification), `onMessageOpenedApp` (background tap → navigate), `getInitialMessage()` (terminated tap → navigate). `registerToken()` is public — also called from `AuthNotifier.build()` on every authenticated start (fire-and-forget).
- `auth_provider.dart` — calls `registerToken()` (fire-and-forget) inside the authenticated branch of `build()`, so the first login session also gets its token registered.

**6 notification types → routes:**
| type | navigates to |
|---|---|
| `ROOM_OPEN` | `/match-lobby/{match_id}` |
| `MATCH_REMINDER` | `/match-lobby/{match_id}` |
| `MATCH_CANCELLED` | `/wallet` |
| `WIN_ANNOUNCEMENT` | `/results` |
| `KYC_APPROVED` | `/profile` |
| `WITHDRAWAL_DONE` | `/wallet` |

**`flutter analyze`: 0 issues.**

#### Phase 9 setup checklist (USER must do before notifications work)
1. **InsForge → Functions → Env/Secrets**, set `FIREBASE_SERVICE_ACCOUNT_JSON` to the **full contents** of your Firebase service account JSON (Firebase Console → Project Settings → Service Accounts → Generate new private key). The value is the entire JSON as a string.
2. Verify `google-services.json` is at `android/app/google-services.json` ✓ (user confirmed done).
3. Run the app on a real Android device (emulators have limited FCM support).
4. Test: send a notification from the admin panel (Phase 10) or call `send-notification` directly with the service-role key as `Authorization: Bearer`.

---

### Phase 9 — FCM Push Notifications (OLD — replaced above)
**Packages:** `firebase_core: ^3.6.0`, `firebase_messaging: ^15.1.3`

**Setup required:** Firebase project → `google-services.json` → `android/app/` (user must do this)

**DB migration needed:** `device_tokens` table

**Edge functions:** `register-device-token`, `send-notification` (admin-triggered)

**6 notification types:** ROOM_OPEN, MATCH_REMINDER, MATCH_CANCELLED, WIN_ANNOUNCEMENT, KYC_APPROVED, WITHDRAWAL_DONE — each navigates to a specific screen on tap

---

### Phase 10 — Admin Panel (Next.js + Vercel) ✓

**Location:** `nexus-arena/admin/` — Next.js 14 App Router + TypeScript + Tailwind 3.4

**DB changes (live):**
- `admin_users` table (id, email, password_hash, name) — separate from InsForge phone auth
- `tournaments.created_by` made nullable (was NOT NULL, broke admin tournament creation)

**Auth flow:** Email + bcrypt password → POST `/api/auth/login` → JWT (`jose`, 8h) stored in httpOnly `SameSite=strict` cookie → middleware verifies on every request → redirect to `/login` if invalid. `bcryptjs` runs in `runtime='nodejs'` route; middleware uses Edge-compatible `jose`.

**Pages built:**

| Page | What it does |
|---|---|
| `/login` | Email+password form, POSTs to `/api/auth/login` |
| `/dashboard` | KPIs: total users, open tournaments, pending KYC, pending withdrawals (count + total Rs), total wallet balance, ongoing matches |
| `/tournaments` | Lists all tournaments with status badges; toggle status buttons; links to Room Set and Declare Results |
| `/tournaments/new` | Create tournament + auto-create match (POST `/api/tournaments`). Inputs: title, mode, type, tier, scheduled_at, entry_fee, max_teams, min_players, prize_1st/2nd/3rd, rules. Sets `room_id_visible_at = scheduled_at - 15min`. Status starts `registration_open`. |
| `/matches/[id]/room` | Set/update room_id + room_password → UPDATE matches; also flips match status to `ongoing`. |
| `/matches/[id]/results` | **Most critical page.** Selects 1st/2nd/3rd place players (dropdown from registered players). Preview: gross prize, TDS 30%, net. On submit: INSERT match_results, `credit_wallet('prize')`, `deduct_wallet('tds')`, UPDATE match+tournament to `completed`, call `send-notification` with WIN_ANNOUNCEMENT. Locked once declared. |
| `/kyc` | Pending KYC submissions with document links (direct to private bucket). APPROVE: UPDATE profiles.kyc_status+'approved' + KYC_APPROVED notification. REJECT: UPDATE with rejection_reason + set to 'rejected'. |
| `/withdrawals` | Pending + history. APPROVE: UPDATE status='completed' + WITHDRAWAL_DONE notification. REJECT: UPDATE status='rejected' + `credit_wallet('refund')` to return funds. |

**Shared utilities:**
- `lib/db.ts` — `getDb()` returns InsForge SDK client with service-role key; `rpc(funcName, params)` for direct PostgREST RPC; `sendNotification()` calls the `send-notification` edge function with service-role Bearer token.
- `lib/auth.ts` — `signAdminToken`, `verifyAdminToken`, `getAdminSession`, cookie helpers.
- `middleware.ts` — protects all routes except `/login`; uses `jose` (Edge runtime).
- `app/(admin)/Sidebar.tsx` — client component; active nav link highlighting; sign-out button.

**Env vars required (copy `.env.local.example` to `.env.local`):**
```
INSFORGE_BASE_URL=https://xymp52ea.ap-southeast.insforge.app
INSFORGE_SERVICE_ROLE_KEY=<service role key from InsForge dashboard>
INSFORGE_FUNCTIONS_URL=https://xymp52ea.functions.insforge.app
ADMIN_JWT_SECRET=<random 32+ char string>
```

**To create the first admin user**, run this SQL (replace hash with bcrypt of your password):
```sql
-- Generate hash: node -e "const b=require('bcryptjs'); console.log(b.hashSync('yourpassword', 10))"
INSERT INTO admin_users (email, password_hash, name) VALUES
  ('admin@nexusarena.in', '$2a$10$your_hash_here', 'Admin');
```

**To run locally:**
```
cd admin && npm install && npm run dev
# Opens at http://localhost:3001
```

**To deploy to Vercel:**
```
cd admin && vercel deploy
# Set the 4 env vars in Vercel dashboard
```

**What was NOT built (Phase 11 will complete):**
- User management page (`/users`) — search by phone, BAN/UNBAN
- Notifications broadcast page (`/notifications`) — bulk FCM send
- App settings page (`/settings`) — maintenance mode flag

---

### Phase 10 — Admin Panel (Next.js + Vercel) [OLD stub below]
Located in `nexus-arena/admin/` (not yet created)

**Key pages:** Dashboard, Match Management, Room Entry, Result Declaration (locks after declare + auto TDS + credit_wallet for winners), User Management, KYC Review, Withdrawal Approval, Notifications broadcast

**Uses InsForge service-role key server-side.** Result declaration must call `credit_wallet()` RPC for each winner and trigger FCM.

---

### Phase 11 — Testing + Bug Fixes
See full test checklist in the build plan at `C:\Users\Avi\.claude\plans\iridescent-soaring-rabin.md`

---

### Phase 12 — APK Build + Play Store
`applicationId = com.nexusarena.app`  
Build: `flutter build appbundle --release --dart-define=INSFORGE_ANON_KEY=<key> --dart-define=RAZORPAY_KEY_ID=<key>`

---

## Key Architecture Decisions

| Decision | Reason |
|---|---|
| All amounts in paise (bigint) in DB | Avoids floating-point errors; display layer divides by 100 |
| `entry_fee` stored in Rs (int) in DB | Historical — the original schema used Rs directly; convert to paise (`* 100`) when calling `deduct_wallet()` |
| `deduct_wallet()` / `credit_wallet()` are the ONLY paths to mutate wallet | SECURITY DEFINER functions — direct UPDATE on wallets is blocked by RLS |
| JWT decoded client-side in edge functions | Avoids extra round-trip; InsForge JWTs are short-lived (24h). Service role key used for all DB ops |
| `share_plus ^12.0.2` (not ^9.0.0) | Version conflict with `cached_network_image` over `web` package — upgraded to resolve |
| `withOpacity()` → `withValues(alpha:)` | `withOpacity` deprecated in Dart 3.7+; project uses SDK `^3.12.0` |
| `(_, __)` → `(_, _)` in lambdas | `unnecessary_underscores` lint rule in Dart 3.12 |
| Manual Riverpod `AsyncNotifier` (no codegen) | `riverpod_generator` is in pubspec but not used yet — avoids requiring `build_runner` for every session |

---

## Test Data in DB

| Item | Details |
|---|---|
| Tournaments | 4 seeded: "Free Fire Solo Blitz" (OPEN, ₹50), "Free Fire Solo Elite" (OPEN, ₹100), "Free Fire Duo Cup T1" (OPEN, ₹100), "Free Fire Squad War T1" (ONGOING, ₹250) |
| Match | 1 seeded for "Free Fire Solo Blitz" — Room ID: `NX-7742`, Password: `nexus2024` |
| Users | Created via OTP flow (phone +91XXXXXXXXXX) |

**To test join flow (add wallet balance):**
```sql
SELECT credit_wallet('<user-uuid>', 50000, 'deposit', null, null, 'Test top-up ₹500');
```

**To force room open for lobby testing:**
```sql
UPDATE matches SET room_id_visible_at = now() - interval '1 minute' WHERE room_id = 'NX-7742';
```

---

## File Structure (current)

```
nexus-arena/
├── functions/
│   ├── send-otp.ts          ← live
│   ├── verify-otp.ts        ← live
│   └── join-tournament.ts   ← live (Phase 3)
├── migrations/
│   ├── 20260531*            ← 7 original migrations
│   └── 20260601000001_update-tournament-schema.sql
├── nexus_arena/lib/
│   ├── main.dart            ← ProviderScope wrapper
│   ├── core/
│   │   ├── api_client.dart  ← apikey header, getList(), patch()
│   │   ├── constants.dart
│   │   ├── router.dart      ← 12 routes
│   │   └── theme.dart       ← full color tokens
│   └── features/
│       ├── auth/            ← phone + OTP screens (done), auth_provider
│       ├── home/            ← home_screen, section_header (done)
│       ├── tournaments/     ← detail, card, join_bottom_sheet, prize_breakdown, providers, services (done)
│       ├── matches/         ← lobby, room_card, lobby_countdown, match_service (done)
│       ├── wallet/          ← STUB screens (Phase 5 next), wallet_provider, wallet_service
│       ├── profile/         ← STUB screen, profile_service, Profile model
│       ├── results/         ← STUB screen
│       ├── kyc/             ← STUB screen
│       └── settings/        ← STUB screen
└── CLAUDE.md
```

---

## Run Command

```
flutter run --dart-define=INSFORGE_ANON_KEY=<your_anon_key>
```

Anon key is in InsForge dashboard → Project Settings → API Keys.
