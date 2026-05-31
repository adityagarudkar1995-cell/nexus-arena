CREATE TABLE matches (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id       uuid NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  room_id             text,                        -- null until visible
  room_password       text,
  room_id_visible_at  timestamptz,                 -- tournament.scheduled_at - 15 min
  status              match_status NOT NULL DEFAULT 'pending',
  scheduled_at        timestamptz NOT NULL,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE matches ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER matches_updated_at
  BEFORE UPDATE ON matches
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE INDEX matches_tournament_idx ON matches(tournament_id);

-- Room ID only revealed 15 min before match; registered users can read match metadata
CREATE POLICY "matches: registered users read" ON matches FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM tournament_registrations r
      WHERE r.tournament_id = matches.tournament_id
        AND r.user_id = auth.uid()
        AND r.status NOT IN ('refunded', 'disqualified')
    )
  );

-- Hide room_id and room_password via security-barrier view
CREATE VIEW match_lobby WITH (security_barrier = true) AS
SELECT
  m.id,
  m.tournament_id,
  m.status,
  m.scheduled_at,
  m.room_id_visible_at,
  CASE WHEN now() >= m.room_id_visible_at THEN m.room_id       ELSE NULL END AS room_id,
  CASE WHEN now() >= m.room_id_visible_at THEN m.room_password ELSE NULL END AS room_password
FROM matches m
WHERE EXISTS (
  SELECT 1 FROM tournament_registrations r
  WHERE r.tournament_id = m.tournament_id
    AND r.user_id = auth.uid()
    AND r.status NOT IN ('refunded', 'disqualified')
);

CREATE TABLE match_results (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id        uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  registration_id uuid NOT NULL REFERENCES tournament_registrations(id) ON DELETE CASCADE,
  rank            int NOT NULL CHECK (rank > 0),
  kills           int NOT NULL DEFAULT 0,
  points          int NOT NULL DEFAULT 0,
  prize_amount    bigint NOT NULL DEFAULT 0,       -- paise, before TDS
  tds_amount      bigint NOT NULL DEFAULT 0,       -- 30% of prize_amount
  net_prize       bigint NOT NULL DEFAULT 0,       -- prize_amount - tds_amount
  paid_at         timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),

  UNIQUE (match_id, registration_id)
);

ALTER TABLE match_results ENABLE ROW LEVEL SECURITY;

CREATE INDEX match_results_match_idx        ON match_results(match_id);
CREATE INDEX match_results_registration_idx ON match_results(registration_id);

-- Users can read their own results
CREATE POLICY "match_results: own read" ON match_results FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM tournament_registrations r
      WHERE r.id = match_results.registration_id AND r.user_id = auth.uid()
    )
  );

-- TDS calculation helper: 30% on winnings per business rules
CREATE OR REPLACE FUNCTION calculate_tds(prize_paise bigint)
RETURNS bigint LANGUAGE sql IMMUTABLE AS $$
  SELECT FLOOR(prize_paise * 0.30)::bigint;
$$;
