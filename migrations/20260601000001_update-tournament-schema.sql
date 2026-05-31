-- Drops the restrictive entry_fee CHECK constraint that only allowed
-- solo=50, duo=100, squad=250. NEXUS ARENA has 2 tiers per mode plus
-- weekly tournaments with different fee levels.
-- Also adds placement prize columns, tier, tournament_type, and min_players.

ALTER TABLE tournaments DROP CONSTRAINT entry_fee_matches_mode;

ALTER TABLE tournaments
  ADD COLUMN tournament_type text NOT NULL DEFAULT 'daily'
    CONSTRAINT tournament_type_check CHECK (tournament_type IN ('daily', 'weekly')),
  ADD COLUMN tier        int     NOT NULL DEFAULT 1
    CONSTRAINT tier_check CHECK (tier IN (1, 2)),
  ADD COLUMN prize_1st   bigint  NOT NULL DEFAULT 0,  -- paise
  ADD COLUMN prize_2nd   bigint  NOT NULL DEFAULT 0,  -- paise
  ADD COLUMN prize_3rd   bigint  NOT NULL DEFAULT 0,  -- paise
  ADD COLUMN min_players int     NOT NULL DEFAULT 30; -- auto-cancel threshold
