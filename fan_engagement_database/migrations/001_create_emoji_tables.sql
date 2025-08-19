-- Migration: 001_create_emoji_tables.sql
-- Purpose: Create tables and indexes for emoji assets and reactions per spec
-- Safe to re-run: uses IF NOT EXISTS constructs where applicable

-- Ensure we operate on the public schema
SET search_path TO public;

-- 1) emoji_assets: Catalog of allowed reaction emojis
CREATE TABLE IF NOT EXISTS emoji_assets (
  emoji_id SERIAL PRIMARY KEY,
  emoji_type VARCHAR(50) NOT NULL UNIQUE,
  emoji_path TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT emoji_type_slug_chk CHECK (emoji_type ~ '^[a-z0-9_-]+$'),
  CONSTRAINT emoji_type_lowercase_chk CHECK (emoji_type = lower(emoji_type))
);

-- 2) emoji_reactions: Records of user reactions to an event (e.g., video/stream)
CREATE TABLE IF NOT EXISTS emoji_reactions (
  reaction_id SERIAL PRIMARY KEY,
  event_id VARCHAR(100) NOT NULL,
  user_id VARCHAR(100),
  emoji_id INT NOT NULL REFERENCES emoji_assets(emoji_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Trigger to auto-update updated_at on UPDATE for emoji_reactions
CREATE OR REPLACE FUNCTION set_updated_at_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  -- Create trigger only if not exists
  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'set_emoji_reactions_updated_at'
  ) THEN
    CREATE TRIGGER set_emoji_reactions_updated_at
    BEFORE UPDATE ON emoji_reactions
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at_timestamp();
  END IF;
END;
$$;

-- Recommended indexes for performance and analytics
CREATE INDEX IF NOT EXISTS idx_emoji_reactions_event_id ON emoji_reactions(event_id);
CREATE INDEX IF NOT EXISTS idx_emoji_reactions_emoji_id ON emoji_reactions(emoji_id);
CREATE INDEX IF NOT EXISTS idx_emoji_reactions_event_emoji ON emoji_reactions(event_id, emoji_id);
CREATE INDEX IF NOT EXISTS idx_emoji_reactions_user_event ON emoji_reactions(user_id, event_id);

-- Unique index already provided by UNIQUE(emoji_type) in emoji_assets.
