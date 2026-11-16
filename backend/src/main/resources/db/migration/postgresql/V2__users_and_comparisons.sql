CREATE TABLE app_users (
 id UUID PRIMARY KEY,
 email VARCHAR(254) NOT NULL UNIQUE,
 password_hash VARCHAR(500) NOT NULL
);
CREATE TABLE auth_sessions (
 token_hash VARCHAR(64) PRIMARY KEY,
 user_id UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
 expires_at TIMESTAMPTZ NOT NULL
);
CREATE TABLE comparisons (
 id UUID PRIMARY KEY,
 user_id UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
 title VARCHAR(100) NOT NULL,
 product_ids JSONB NOT NULL,
 preferences JSONB NOT NULL,
 version INTEGER NOT NULL DEFAULT 0,
 updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX comparisons_owner_idx ON comparisons(user_id, updated_at DESC);
