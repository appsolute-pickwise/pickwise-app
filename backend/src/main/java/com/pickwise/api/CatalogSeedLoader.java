package com.pickwise.api;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.sql.Date;
import java.time.LocalDate;
import java.util.HashSet;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
public class CatalogSeedLoader implements ApplicationRunner {
    private final JdbcTemplate jdbc;
    private final ObjectMapper mapper;

    public CatalogSeedLoader(JdbcTemplate jdbc, ObjectMapper mapper) {
        this.jdbc = jdbc;
        this.mapper = mapper;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) throws IOException {
        Long existing = jdbc.queryForObject("SELECT count(*) FROM products", Long.class);
        if (existing != null && existing > 0) return;

        JsonNode products;
        try (var stream = new ClassPathResource("seed/products.json").getInputStream()) {
            products = mapper.readTree(stream);
        }
        if (!products.isArray() || products.isEmpty()) {
            throw new IllegalStateException("Seed catalog must be a non-empty array");
        }
        var ids = new HashSet<String>();
        for (JsonNode product : products) {
            String id = requiredText(product, "id");
            if (!ids.add(id)) throw new IllegalStateException("Duplicate product ID: " + id);
            int price = product.path("price").asInt();
            if (price <= 0) throw new IllegalStateException("Invalid price for " + id);
            jdbc.update("INSERT INTO products(id,brand,name,category,image_asset,price,"
                            + "price_checked_at,price_comparison_site,price_comparison_url) "
                            + "VALUES (?,?,?,?,?,?,?,?,?)",
                    id, requiredText(product, "brand"), requiredText(product, "name"),
                    requiredText(product, "category"), nullableText(product, "imageAsset"),
                    price, Date.valueOf(LocalDate.parse(requiredText(product, "priceCheckedAt"))),
                    requiredText(product, "priceComparisonSite"),
                    requiredText(product, "priceComparisonUrl"));

            int tagPosition = 0;
            for (JsonNode tag : product.path("tags")) {
                jdbc.update("INSERT INTO product_tags(product_id,position,tag) VALUES (?,?,?)",
                        id, tagPosition++, tag.asText());
            }
            int specPosition = 0;
            for (JsonNode spec : product.path("specs")) {
                JsonNode value = spec.get("value");
                if (value == null || (!value.isTextual() && !value.isNumber() && !value.isBoolean())) {
                    throw new IllegalStateException("Invalid specification value for " + id);
                }
                jdbc.update("INSERT INTO product_specifications(product_id,position,`key`,label,"
                                + "value_json,unit,source_url,checked_at) VALUES (?,?,?,?,?,?,?,?)",
                        id, specPosition++, requiredText(spec, "key"), requiredText(spec, "label"),
                        value.toString(), nullableText(spec, "unit"), nullableText(spec, "sourceUrl"),
                        nullableDate(spec, "checkedAt"));
            }
        }
    }

    private static String requiredText(JsonNode node, String key) {
        JsonNode value = node.get(key);
        if (value == null || !value.isTextual() || value.asText().isBlank()) {
            throw new IllegalStateException("Missing catalog field: " + key);
        }
        return value.asText();
    }

    private static String nullableText(JsonNode node, String key) {
        JsonNode value = node.get(key);
        return value == null || value.isNull() ? null : value.asText();
    }

    private static Date nullableDate(JsonNode node, String key) {
        String value = nullableText(node, key);
        return value == null ? null : Date.valueOf(LocalDate.parse(value));
    }
}
