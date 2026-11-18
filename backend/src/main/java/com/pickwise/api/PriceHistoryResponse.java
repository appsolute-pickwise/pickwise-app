package com.pickwise.api;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

public record PriceHistoryResponse(String productId, int days, String kind, Instant asOf,
        String sourceKey, List<Source> sources, List<Point> points, long total, boolean truncated) {
    public record Source(String key, String site, String url, boolean current, long count) {}
    public record Point(long id, int price, Instant observedAt, LocalDate checkedAt) {}
}
