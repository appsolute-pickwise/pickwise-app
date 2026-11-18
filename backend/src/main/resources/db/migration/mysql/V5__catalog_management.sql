ALTER TABLE app_users ADD is_admin BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE products
 ADD version INTEGER NOT NULL DEFAULT 0,
 ADD price_auto_refresh BOOLEAN NOT NULL DEFAULT TRUE;

CREATE TABLE product_changes (
 id BIGINT AUTO_INCREMENT PRIMARY KEY,
 product_id VARCHAR(120) NOT NULL,
 actor_id CHAR(36) NOT NULL,
 action VARCHAR(20) NOT NULL,
 before_json JSON NULL,
 after_json JSON NOT NULL,
 changed_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 FOREIGN KEY (product_id) REFERENCES products(id),
 FOREIGN KEY (actor_id) REFERENCES app_users(id)
);
CREATE INDEX product_changes_product_idx ON product_changes(product_id, id);
