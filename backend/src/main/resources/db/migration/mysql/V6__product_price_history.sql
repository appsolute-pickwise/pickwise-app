CREATE TABLE product_price_history (
 id BIGINT AUTO_INCREMENT PRIMARY KEY,
 product_id VARCHAR(120) NOT NULL,
 product_version INTEGER NOT NULL,
 price INTEGER NOT NULL CHECK (price > 0),
 kind VARCHAR(16) NOT NULL CHECK (kind IN ('automatic','manual')),
 source_site VARCHAR(40) NOT NULL,
 source_url VARCHAR(1000) NOT NULL,
 source_key CHAR(64) NOT NULL,
 observed_at TIMESTAMP(6) NOT NULL,
 checked_at DATE NOT NULL,
 recorded_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
 UNIQUE (product_id, product_version)
);
CREATE INDEX price_history_lookup_idx
 ON product_price_history(product_id, kind, source_key, observed_at, id);

-- 실제 마지막 정상 조회가 확인되는 기존 값 한 건만 보존한다. 수동 가격의 과거 이력은 추정하지 않는다.
INSERT INTO product_price_history
 (product_id,product_version,price,kind,source_site,source_url,source_key,observed_at,checked_at)
 SELECT id,version,price,'automatic',price_comparison_site,price_comparison_url,
 SHA2(CONCAT(price_comparison_site,CHAR(10),price_comparison_url),256),price_fetched_at,price_checked_at
 FROM products WHERE price_fetched_at IS NOT NULL;
