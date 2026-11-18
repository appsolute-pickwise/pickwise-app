CREATE TABLE product_watches (
 id CHAR(36) PRIMARY KEY,
 user_id CHAR(36) NOT NULL,
 product_id VARCHAR(120) NOT NULL,
 target_price INTEGER NULL CHECK (target_price > 0),
 source_key CHAR(64) NOT NULL,
 version INTEGER NOT NULL DEFAULT 0,
 armed BOOLEAN NOT NULL DEFAULT FALSE,
 updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 UNIQUE(user_id,product_id),
 FOREIGN KEY(user_id) REFERENCES app_users(id) ON DELETE CASCADE,
 FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE
);
CREATE TABLE price_alerts (
 id CHAR(36) PRIMARY KEY,
 user_id CHAR(36) NOT NULL,
 watch_id CHAR(36) NULL,
 rule_version INTEGER NOT NULL,
 product_id VARCHAR(120) NOT NULL,
 product_name VARCHAR(240) NOT NULL,
 price INTEGER NOT NULL,
 target_price INTEGER NOT NULL,
 source_url VARCHAR(1000) NOT NULL,
 observed_at TIMESTAMP(6) NOT NULL,
 read_at TIMESTAMP(6) NULL,
 UNIQUE(watch_id,rule_version),
 FOREIGN KEY(user_id) REFERENCES app_users(id) ON DELETE CASCADE,
 FOREIGN KEY(watch_id) REFERENCES product_watches(id) ON DELETE SET NULL
);
CREATE INDEX price_alert_owner_idx ON price_alerts(user_id,observed_at,id);
