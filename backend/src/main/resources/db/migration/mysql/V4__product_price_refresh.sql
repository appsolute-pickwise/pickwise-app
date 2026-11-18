ALTER TABLE products
 ADD price_fetched_at TIMESTAMP(6) NULL,
 ADD price_attempted_at TIMESTAMP(6) NULL,
 ADD price_refresh_status VARCHAR(20) NOT NULL DEFAULT 'manual';
