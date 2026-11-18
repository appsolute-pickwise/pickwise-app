CREATE TABLE push_devices (
 token_hash CHAR(64) PRIMARY KEY,
 user_id CHAR(36) NOT NULL,
 device_token VARCHAR(4096) NOT NULL,
 platform VARCHAR(16) NOT NULL,
 updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 FOREIGN KEY(user_id) REFERENCES app_users(id) ON DELETE CASCADE
);
CREATE TABLE alert_deliveries (
 alert_id CHAR(36) NOT NULL,
 token_hash CHAR(64) NOT NULL,
 status VARCHAR(16) NOT NULL DEFAULT 'pending',
 attempts INTEGER NOT NULL DEFAULT 0,
 attempted_at TIMESTAMP(6) NULL,
 PRIMARY KEY(alert_id,token_hash),
 FOREIGN KEY(alert_id) REFERENCES price_alerts(id) ON DELETE CASCADE,
 FOREIGN KEY(token_hash) REFERENCES push_devices(token_hash) ON DELETE CASCADE
);
