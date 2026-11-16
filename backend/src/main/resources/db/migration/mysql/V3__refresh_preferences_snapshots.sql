DELETE FROM auth_sessions;
ALTER TABLE auth_sessions ADD refresh_hash VARCHAR(64) NULL UNIQUE,
 ADD refresh_expires_at TIMESTAMP(6) NULL;
CREATE TABLE user_preferences (
 user_id CHAR(36) PRIMARY KEY,
 preferences JSON NOT NULL,
 FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE
);
ALTER TABLE comparisons ADD snapshot JSON NULL;
