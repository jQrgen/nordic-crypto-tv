-- Nordic Crypto app push server. Only what is needed to deliver a notification:
-- the push token, the platform, the APNs environment, the language and the countries.
-- No account, no IP address, no device name, no user agent.
CREATE TABLE IF NOT EXISTS devices (
  token TEXT PRIMARY KEY,
  platform TEXT NOT NULL,                       -- ios | ipados | macos | visionos | android
  environment TEXT NOT NULL DEFAULT 'production', -- APNs: production | sandbox (Xcode debug builds)
  language TEXT NOT NULL DEFAULT 'en',
  countries TEXT NOT NULL,                      -- ",NO,SE," (leading and trailing comma)
  updated_at INTEGER NOT NULL                   -- ms; devices not seen for 180 days are removed
);

-- Story ids already seen in the feed. item is the story (public data) while it may still be sent.
CREATE TABLE IF NOT EXISTS stories (
  id TEXT PRIMARY KEY,
  seen_at INTEGER NOT NULL,
  item TEXT
);

-- One row per notification still to send. Rows expire after six hours.
CREATE TABLE IF NOT EXISTS deliveries (
  story_id TEXT NOT NULL,
  token TEXT NOT NULL,
  queued_at INTEGER NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (story_id, token)
);
CREATE INDEX IF NOT EXISTS deliveries_queued ON deliveries(queued_at);
CREATE INDEX IF NOT EXISTS deliveries_token ON deliveries(token);

-- Feed ETag, first-run marker and short-lived provider tokens (APNs JWT, FCM access token).
CREATE TABLE IF NOT EXISTS state (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
