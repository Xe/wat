CREATE TABLE IF NOT EXISTS users
  ( uuid TEXT UNIQUE
  , fullname TEXT UNIQUE
  , email TEXT UNIQUE
  , pw_hash TEXT
  , is_advertiser INTEGER
  , created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  , deleted_at INTEGER
  );

CREATE UNIQUE INDEX IF NOT EXISTS user_uuid ON users(uuid);

CREATE TABLE IF NOT EXISTS images
  ( uuid TEXT UNIQUE
  , image BLOB
  );

CREATE UNIQUE INDEX IF NOT EXISTS image_uuid ON images(uuid);

CREATE TABLE IF NOT EXISTS campaigns
  ( uuid TEXT UNIQUE
  , creator TEXT
  , title TEXT
  , box_image_id TEXT
  , plaintext TEXT
  , target_url TEXT
  , created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  , updated_at TIMESTAMP
  , deleted_at TIMESTAMP
  , FOREIGN KEY (creator)
    REFERENCES users(uuid)
  , FOREIGN KEY (box_image_id)
    REFERENCES images(uuid)
  );

CREATE UNIQUE INDEX IF NOT EXISTS campaign_uuid ON campaigns(uuid);
CREATE INDEX IF NOT EXISTS campaign_creator_uuid ON campaigns(uuid, creator);

-- CREATE TRIGGER IF NOT EXISTS campaigns_update_updated_at
--   UPDATE OF plaintext, box_image_id
--   ON campaigns
--   BEGIN
--     UPDATE campaigns SET updated_at=CURRENT_TIMESTAMP WHERE uuid=old.uuid;
--   END;

CREATE TABLE IF NOT EXISTS tokens
  ( uuid TEXT UNIQUE
  , creator TEXT
  , token TEXT UNIQUE
  , created_at TIMESTAMP DEFAULT (DATETIME('now'))
  , deleted_at TIMESTAMP
  , FOREIGN KEY (creator)
    REFERENCES users(uuid)
  );
