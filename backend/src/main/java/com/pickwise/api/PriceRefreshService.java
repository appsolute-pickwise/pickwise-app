package com.pickwise.api;

import java.sql.Timestamp;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.concurrent.atomic.AtomicBoolean;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

@Service
public class PriceRefreshService {
    private static final Logger log = LoggerFactory.getLogger(PriceRefreshService.class);
    private static final Duration INTERVAL = Duration.ofHours(1);
    private final JdbcTemplate jdbc;
    private final DanawaPriceClient client;
    private final boolean enabled;
    private final Clock clock;
    private final PriceHistoryRepository history;
    private final Duration requestSpacing;
    private final AtomicBoolean running = new AtomicBoolean();
    private Instant blockedUntil = Instant.MIN;

    @org.springframework.beans.factory.annotation.Autowired
    public PriceRefreshService(JdbcTemplate jdbc, DanawaPriceClient client,
            @Value("${pickwise.price-refresh.enabled:false}") boolean enabled, PriceHistoryRepository history) {
        this(jdbc, client, enabled, Clock.systemUTC(), Duration.ofSeconds(2), history);
    }

    PriceRefreshService(JdbcTemplate jdbc, DanawaPriceClient client, boolean enabled,
            Clock clock, Duration requestSpacing, PriceHistoryRepository history) {
        this.jdbc = jdbc;
        this.history = history;
        this.client = client;
        this.enabled = enabled;
        this.clock = clock;
        this.requestSpacing = requestSpacing;
    }

    @Scheduled(initialDelay = 30000, fixedDelay = 60000)
    public void refreshDuePrices() {
        if (!enabled || !running.compareAndSet(false, true)) return;
        try {
            if (clock.instant().isBefore(blockedUntil)) return;
            Timestamp cutoff = Timestamp.from(clock.instant().minus(INTERVAL));
            var products = jdbc.query("SELECT id,price_comparison_url,version FROM products "
                            + "WHERE price_comparison_site='danawa' AND price_auto_refresh=TRUE AND "
                            + "(price_attempted_at IS NULL OR price_attempted_at<=?) "
                            + "ORDER BY price_attempted_at,id LIMIT 20",
                    (rs, n) -> new Source(rs.getString(1), rs.getString(2), rs.getInt(3)), cutoff);
            for (var product : products) {
                if (!client.supports(product.url())) continue;
                // HTTP 요청 동안 DB 트랜잭션을 잡지 않고, 시도 시각으로 중복 수집을 제한한다.
                int claimed = jdbc.update("UPDATE products SET price_attempted_at=? "
                                + "WHERE id=? AND price_comparison_url=? AND version=? AND price_auto_refresh=TRUE AND "
                                + "(price_attempted_at IS NULL OR price_attempted_at<=?)",
                        Timestamp.from(clock.instant()), product.id(), product.url(), product.version(), cutoff);
                if (claimed == 0) continue;
                try {
                    int price = client.fetch(product.url());
                    Instant received = clock.instant();
                    history.recordAutomatic(product.id(),product.url(),product.version(),price,received);
                } catch (Exception error) {
                    jdbc.update("UPDATE products SET price_refresh_status='failed' "
                                    + "WHERE id=? AND price_comparison_url=? AND version=? AND price_auto_refresh=TRUE", product.id(), product.url(), product.version());
                    log.warn("Price refresh failed for {} ({})", product.id(), error.getClass().getSimpleName());
                    if (error instanceof InterruptedException) {
                        Thread.currentThread().interrupt();
                        return;
                    }
                    if (error instanceof DanawaPriceClient.RateLimitedException) {
                        blockedUntil = clock.instant().plus(INTERVAL);
                        return;
                    }
                }
                try {
                    Thread.sleep(requestSpacing);
                } catch (InterruptedException error) {
                    Thread.currentThread().interrupt();
                    return;
                }
            }
        } finally {
            running.set(false);
        }
    }

    private record Source(String id, String url, int version) {}
}
