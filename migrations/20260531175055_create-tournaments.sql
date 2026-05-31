CREATE TABLE tournaments (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title            text NOT NULL,
  game             text NOT NULL,                   -- 'BGMI', 'Free Fire', 'COD Mobile', etc.
  mode             game_mode NOT NULL,
  entry_fee        int NOT NULL,                    -- Rs: 50 (solo) / 100 (duo) / 250 (squad)
  prize_pool       bigint NOT NULL DEFAULT 0,       -- paise
  max_teams        int NOT NULL,
  registered_count int NOT NULL DEFAULT 0,
  status           tournament_status NOT NULL DEFAULT 'draft',
  scheduled_at     timestamptz NOT NULL,
  rules            text,
  banner_url       text,
  created_by       uuid NOT NULL REFERENCES auth.users(id),
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT entry_fee_matches_mode CHECK (
    (mode = 'solo'  AND entry_fee = 50)  OR
    (mode = 'duo'   AND entry_fee = 100) OR
    (mode = 'squad' AND entry_fee = 250)
  )
);

ALTER TABLE tournaments ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER tournaments_updated_at
  BEFORE UPDATE ON tournaments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Anyone can browse open tournaments; only admins write (enforced at function layer)
CREATE POLICY "tournaments: public read" ON tournaments FOR SELECT USING (status != 'draft');

CREATE TABLE tournament_registrations (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id          uuid NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  user_id                uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  team_name              text,
  team_members           uuid[],                     -- co-players for duo/squad
  status                 registration_status NOT NULL DEFAULT 'registered',
  payment_transaction_id uuid REFERENCES wallet_transactions(id),
  registered_at          timestamptz NOT NULL DEFAULT now(),

  UNIQUE (tournament_id, user_id)
);

ALTER TABLE tournament_registrations ENABLE ROW LEVEL SECURITY;

CREATE INDEX registrations_tournament_idx ON tournament_registrations(tournament_id);
CREATE INDEX registrations_user_idx       ON tournament_registrations(user_id);

-- Users see only their own registrations
CREATE POLICY "registrations: own read" ON tournament_registrations FOR SELECT USING (auth.uid() = user_id);

-- Increment registered_count after a successful registration
CREATE OR REPLACE FUNCTION increment_registered_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  UPDATE tournaments
  SET registered_count = registered_count + 1
  WHERE id = NEW.tournament_id;
  RETURN NEW;
END;
$$;

CREATE TRIGGER after_registration_insert
  AFTER INSERT ON tournament_registrations
  FOR EACH ROW EXECUTE FUNCTION increment_registered_count();

-- Decrement on refund/cancellation
CREATE OR REPLACE FUNCTION decrement_registered_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status IN ('refunded', 'disqualified') AND OLD.status = 'registered' THEN
    UPDATE tournaments
    SET registered_count = GREATEST(registered_count - 1, 0)
    WHERE id = NEW.tournament_id;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER after_registration_status_change
  AFTER UPDATE OF status ON tournament_registrations
  FOR EACH ROW EXECUTE FUNCTION decrement_registered_count();
