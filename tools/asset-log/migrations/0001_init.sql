-- One row per PixelLab call (one seed). Review fields are only changed by the web app / asset_log.py pull.
CREATE TABLE generations (
  id TEXT PRIMARY KEY,            -- <sprite>~<seed>~<unix time>
  sprite TEXT NOT NULL,
  prefix TEXT NOT NULL,           -- room_, ic_, en_ ...
  endpoint TEXT NOT NULL,
  seed INTEGER NOT NULL,
  t INTEGER NOT NULL,
  w INTEGER NOT NULL, h INTEGER NOT NULL,          -- native sprite size
  gen_w INTEGER NOT NULL, gen_h INTEGER NOT NULL,  -- size sent to PixelLab
  usd REAL NOT NULL DEFAULT 0,
  prompt TEXT NOT NULL DEFAULT '',
  negative TEXT NOT NULL DEFAULT '',
  prompt_guess INTEGER NOT NULL DEFAULT 0,  -- 1 = old log line without a prompt, filled from prompts.json
  params TEXT NOT NULL DEFAULT '{}',        -- JSON: strength, guidance, outline, shading, style ...
  key_raw TEXT, key_snapped TEXT, key_current TEXT,  -- R2 object keys
  off_palette INTEGER,            -- snapped pixels not in the master palette (should be 0)
  size_ok INTEGER,                -- snapped size == native size
  status TEXT NOT NULL DEFAULT 'new',  -- new | approved | rejected | accepted
  note TEXT NOT NULL DEFAULT '',
  reviewed_by TEXT NOT NULL DEFAULT '',
  reviewed_at INTEGER
);
CREATE INDEX gen_sprite ON generations(sprite, t);
CREATE INDEX gen_status ON generations(status, t);
CREATE INDEX gen_t ON generations(t);

-- Latest values uploaded by asset_log.py sync: balance, palette, atlas, prompts.
CREATE TABLE snapshots (
  kind TEXT NOT NULL,
  t INTEGER NOT NULL,
  value TEXT NOT NULL,
  PRIMARY KEY (kind, t)
);
