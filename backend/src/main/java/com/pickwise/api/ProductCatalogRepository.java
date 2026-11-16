package com.pickwise.api;

import tools.jackson.core.JacksonException;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import java.sql.Date;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class ProductCatalogRepository {
    private final NamedParameterJdbcTemplate jdbc;
    private final ObjectMapper mapper;

    public ProductCatalogRepository(NamedParameterJdbcTemplate jdbc, ObjectMapper mapper) {
        this.jdbc = jdbc;
        this.mapper = mapper;
    }

    public ProductPage findPage(String category, String query, String sort, int page, int size) {
        var params = new MapSqlParameterSource()
                .addValue("limit", size)
                .addValue("offset", (long) page * size);
        var conditions = new ArrayList<String>();
        if (category != null) {
            conditions.add("category = :category");
            params.addValue("category", category);
        }
        if (query != null) {
            conditions.add("LOWER(CONCAT(brand, ' ', name)) LIKE LOWER(:query) ESCAPE '!'");
            params.addValue("query", "%" + escapeLike(query) + "%");
        }
        String where = conditions.isEmpty() ? "" : "WHERE " + String.join(" AND ", conditions);
        long total = jdbc.queryForObject("SELECT count(*) FROM products " + where, params, Long.class);
        String order = switch (sort) {
            case "priceAsc" -> "price ASC, id ASC";
            case "priceDesc" -> "price DESC, id ASC";
            default -> "name ASC, id ASC";
        };
        List<ProductRow> rows = jdbc.query(
                "SELECT * FROM products " + where + " ORDER BY " + order + " LIMIT :limit OFFSET :offset",
                params,
                (rs, rowNum) -> row(rs));
        return new ProductPage(assemble(rows), page, size, total);
    }

    public Optional<ProductResponse> findById(String id) {
        List<ProductRow> rows = jdbc.query(
                "SELECT * FROM products WHERE id = :id",
                new MapSqlParameterSource("id", id),
                (rs, rowNum) -> row(rs));
        List<ProductResponse> products = assemble(rows);
        return products.isEmpty() ? Optional.empty() : Optional.of(products.getFirst());
    }

    public long count() {
        return jdbc.getJdbcTemplate().queryForObject("SELECT count(*) FROM products", Long.class);
    }

    private List<ProductResponse> assemble(List<ProductRow> rows) {
        if (rows.isEmpty()) return List.of();
        List<String> ids = rows.stream().map(ProductRow::id).toList();
        var params = new MapSqlParameterSource("ids", ids);
        Map<String, List<String>> tags = new LinkedHashMap<>();
        Map<String, List<ProductResponse.Specification>> specs = new LinkedHashMap<>();

        jdbc.query("SELECT product_id, tag FROM product_tags WHERE product_id IN (:ids) "
                        + "ORDER BY product_id, position", params, rs -> {
                    tags.computeIfAbsent(rs.getString("product_id"), ignored -> new ArrayList<>())
                            .add(rs.getString("tag"));
                });
        jdbc.query("SELECT product_id, `key`, label, value_json, unit, "
                        + "source_url, checked_at FROM product_specifications "
                        + "WHERE product_id IN (:ids) ORDER BY product_id, position", params, rs -> {
                    specs.computeIfAbsent(rs.getString("product_id"), ignored -> new ArrayList<>())
                            .add(specification(rs));
                });

        return rows.stream().map(product -> new ProductResponse(
                product.id(), product.brand(), product.name(), product.category(),
                product.imageAsset(), List.copyOf(tags.getOrDefault(product.id(), List.of())),
                product.price(), product.priceCheckedAt(), product.priceComparisonSite(),
                product.priceComparisonUrl(),
                List.copyOf(specs.getOrDefault(product.id(), List.of())))).toList();
    }

    private ProductResponse.Specification specification(ResultSet rs) throws SQLException {
        try {
            JsonNode value = mapper.readTree(rs.getString("value_json"));
            return new ProductResponse.Specification(
                    rs.getString("key"), rs.getString("label"), value,
                    rs.getString("unit"), rs.getString("source_url"), date(rs, "checked_at"));
        } catch (JacksonException error) {
            throw new IllegalStateException("Invalid specification JSON in database", error);
        }
    }

    private static ProductRow row(ResultSet rs) throws SQLException {
        return new ProductRow(
                rs.getString("id"), rs.getString("brand"), rs.getString("name"),
                rs.getString("category"), rs.getString("image_asset"),
                rs.getInt("price"), date(rs, "price_checked_at"),
                rs.getString("price_comparison_site"), rs.getString("price_comparison_url"));
    }

    private static LocalDate date(ResultSet rs, String column) throws SQLException {
        Date value = rs.getDate(column);
        return value == null ? null : value.toLocalDate();
    }

    private static String escapeLike(String value) {
        return value.replace("!", "!!").replace("%", "!%").replace("_", "!_");
    }

    private record ProductRow(String id, String brand, String name, String category,
                              String imageAsset, int price, LocalDate priceCheckedAt,
                              String priceComparisonSite, String priceComparisonUrl) {}
}
