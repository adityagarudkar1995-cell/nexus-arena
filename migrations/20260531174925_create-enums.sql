-- KYC verification state
CREATE TYPE kyc_status AS ENUM ('pending', 'submitted', 'approved', 'rejected');

-- Wallet movement types (immutable ledger)
CREATE TYPE transaction_type AS ENUM ('deposit', 'withdrawal', 'entry_fee', 'prize', 'tds', 'refund');

-- Tournament lifecycle
CREATE TYPE tournament_status AS ENUM ('draft', 'registration_open', 'registration_closed', 'ongoing', 'completed', 'cancelled');

-- Game mode determines entry fee
CREATE TYPE game_mode AS ENUM ('solo', 'duo', 'squad');

-- Registration lifecycle
CREATE TYPE registration_status AS ENUM ('registered', 'checked_in', 'playing', 'completed', 'disqualified', 'refunded');

-- Match state
CREATE TYPE match_status AS ENUM ('pending', 'live', 'completed', 'cancelled');

-- Withdrawal payout state
CREATE TYPE withdrawal_status AS ENUM ('pending', 'processing', 'completed', 'failed', 'rejected');
