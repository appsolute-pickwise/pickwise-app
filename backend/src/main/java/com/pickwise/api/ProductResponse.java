package com.pickwise.api;

import tools.jackson.databind.JsonNode;
import java.time.LocalDate;
import java.util.List;

public record ProductResponse(
        String id,
        String brand,
        String name,
        String category,
        String imageAsset,
        List<String> tags,
        int price,
        LocalDate priceCheckedAt,
        String priceComparisonSite,
        String priceComparisonUrl,
        List<Specification> specs,
        java.time.Instant priceFetchedAt,
        java.time.Instant priceAttemptedAt,
        String priceRefreshStatus,
        int version,
        boolean priceAutoRefresh
) {
    public record Specification(
            String key,
            String label,
            JsonNode value,
            String unit,
            String sourceUrl,
            LocalDate checkedAt
    ) {}
}
