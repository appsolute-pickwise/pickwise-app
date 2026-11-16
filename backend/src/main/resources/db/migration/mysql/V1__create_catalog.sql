CREATE TABLE products (
    id VARCHAR(120) PRIMARY KEY,
    brand VARCHAR(120) NOT NULL,
    name VARCHAR(240) NOT NULL,
    category VARCHAR(80) NOT NULL,
    image_asset VARCHAR(400),
    price INTEGER NOT NULL CHECK (price > 0),
    price_checked_at DATE NOT NULL,
    price_comparison_site VARCHAR(40) NOT NULL,
    price_comparison_url VARCHAR(1000) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
);

CREATE TABLE product_tags (
    product_id VARCHAR(120) NOT NULL,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    position SMALLINT NOT NULL CHECK (position >= 0),
    tag VARCHAR(100) NOT NULL,
    PRIMARY KEY (product_id, position)
);

CREATE TABLE product_specifications (
    product_id VARCHAR(120) NOT NULL,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    position SMALLINT NOT NULL CHECK (position >= 0),
    `key` VARCHAR(100) NOT NULL,
    label VARCHAR(120) NOT NULL,
    value_json JSON NOT NULL,
    unit VARCHAR(40),
    source_url VARCHAR(1000),
    checked_at DATE,
    PRIMARY KEY (product_id, position),
    UNIQUE (product_id, `key`)
);

CREATE INDEX products_category_name_idx ON products (category, name, id);
CREATE INDEX products_price_id_idx ON products (price, id);
