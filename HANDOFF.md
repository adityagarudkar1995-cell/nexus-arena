# NEXUS ARENA — Handoff Document
**Last updated:** 2026-06-01  
**Status:** Phase 4 complete. Phase 5 (Wallet) is next.

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

## Pending Phases

### Phase 5 — Wallet Screen + Transaction History
**Files to create:**
- `features/wallet/screens/wallet_screen.dart` — Replace stub. Balance card (large green), ADD MONEY + WITHDRAW buttons, stats row (Total Added / Won / Withdrawn), filter tabs (All/Added/Won/Entry Fee/Withdrawn/Refund), paginated transaction list (20 per page), shimmer loading
- `features/wallet/widgets/balance_card.dart`
- `features/wallet/widgets/transaction_tile.dart` — type icon + color (green credit / red debit)
- `features/wallet/widgets/wallet_stats_row.dart`

**Notes:** `wallet_transactions.amount` is positive for credit, negative for debit. Stats are in `wallets` table directly (`total_deposited`, `total_won`, `total_withdrawn`). All amounts in paise → divide by 100 for display.

---

### Phase 6 — Razorpay Payment Integration
**Packages to add:** `razorpay_flutter: ^1.3.6`

**Edge functions to build:**
- `create-razorpay-order` — validates amount (min ₹50, max ₹10,000), calls Razorpay `/v1/orders`, stores in new `razorpay_orders` table, returns `{ order_id, amount, key_id }`
- `verify-razorpay-payment` — HMAC-SHA256 signature check, idempotency via `razorpay_payment_id` unique constraint, calls `credit_wallet()` RPC
- `razorpay-webhook` — server-side backup verification (same credit logic, idempotent)

**DB migration needed:** `razorpay_orders` table (user_id, razorpay_order_id UNIQUE, razorpay_payment_id UNIQUE, amount_paise, status)

**Files to create:** `features/wallet/screens/add_money_screen.dart`, `features/wallet/services/payment_service.dart`, `features/wallet/widgets/amount_preset_chip.dart`

**Preset amounts:** ₹50 / ₹100 / ₹200 / ₹500 / ₹1000 + custom input. Use Razorpay test keys first.

---

### Phase 7 — Withdrawal + KYC
**Packages to add:** `image_picker: ^1.1.2`

**Edge function:** `request-withdrawal` — verifies KYC approved (DB trigger also checks), verifies daily limit, calls `deduct_wallet()`, inserts into `withdrawals`

**Files:** `features/wallet/screens/withdraw_screen.dart`, `features/kyc/screens/kyc_screen.dart` (step-based PageView: Aadhaar → PAN → Selfie → Status), `features/kyc/services/kyc_service.dart`

**KYC images:** Upload to InsForge Storage bucket `kyc-documents` (private). Check if bucket exists first.

**Withdrawal DB trigger already live:** Enforces KYC approved + ₹10,000/day cap at DB level.

---

### Phase 8 — Profile + Settings
**Files:** `features/profile/screens/profile_screen.dart`, `features/profile/screens/edit_profile_screen.dart`, `features/settings/screens/settings_screen.dart`

**24-hour edit lock:** `Profile.canEditProfile` getter already implemented — checks `updatedAt` vs now.

**Stats to show:** Matches played, Wins, Total Earned — need an edge function or a DB view since these require joining across tables.

---

### Phase 9 — FCM Push Notifications
**Packages:** `firebase_core: ^3.6.0`, `firebase_messaging: ^15.1.3`

**Setup required:** Firebase project → `google-services.json` → `android/app/` (user must do this)

**DB migration needed:** `device_tokens` table

**Edge functions:** `register-device-token`, `send-notification` (admin-triggered)

**6 notification types:** ROOM_OPEN, MATCH_REMINDER, MATCH_CANCELLED, WIN_ANNOUNCEMENT, KYC_APPROVED, WITHDRAWAL_DONE — each navigates to a specific screen on tap

---

### Phase 10 — Admin Panel (Next.js + Vercel)
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
