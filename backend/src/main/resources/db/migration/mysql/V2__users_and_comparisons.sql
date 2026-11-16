CREATE TABLE app_users (
 id CHAR(36) PRIMARY KEY,
 email VARCHAR(254) NOT NULL UNIQUE,
 password_hash VARCHAR(500) NOT NULL
);
CREATE TABLE auth_sessions (
 token_hash VARCHAR(64) PRIMARY KEY,
 user_id CHAR(36) NOT NULL,
 FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE,
 expires_at TIMESTAMP(6) NOT NULL
);
CREATE TABLE comparisons (
 id CHAR(36) PRIMARY KEY,
 user_id CHAR(36) NOT NULL,
 FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE,
 title VARCHAR(100) NOT NULL,
 product_ids JSON NOT NULL,
 preferences JSON NOT NULL,
 version INTEGER NOT NULL DEFAULT 0,
 updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
);
CREATE INDEX comparisons_owner_idx ON comparisons(user_id, updated_at DESC);
