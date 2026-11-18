package com.pickwise.api;

import static org.assertj.core.api.Assertions.*;
import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.net.URI;
import java.net.http.HttpClient;
import java.sql.Timestamp;
import java.time.*;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.ObjectMapper;

@SpringBootTest @ActiveProfiles("test") @Transactional
class PriceRefreshIntegrationTest {
    @Autowired JdbcTemplate jdbc;
    @Autowired ObjectMapper mapper;
    @Autowired ProductCatalogRepository repository;
    @Autowired PriceHistoryRepository history;
    HttpServer server;
    PriceRefreshService service;
    AtomicInteger requests = new AtomicInteger();
    String body = DanawaPriceClientTest.html("27250154", "222222");
    int status = 200;
    Instant now = Instant.parse("2026-11-16T02:00:00Z");

    @BeforeEach void start() throws Exception {
        jdbc.update("UPDATE products SET price_attempted_at=?", Timestamp.from(now));
        jdbc.update("UPDATE products SET price_attempted_at=NULL WHERE id='sony-wf-1000xm5'");
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/info/", exchange -> {
            requests.incrementAndGet();
            byte[] bytes = body.getBytes(java.nio.charset.StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type", "text/html");
            exchange.sendResponseHeaders(status, bytes.length);
            exchange.getResponseBody().write(bytes);
            exchange.close();
        });
        server.start();
        var client = new DanawaPriceClient(mapper, HttpClient.newHttpClient(),
                URI.create("http://127.0.0.1:" + server.getAddress().getPort()), Duration.ofSeconds(2));
        service = new PriceRefreshService(jdbc, client, true, Clock.fixed(now, ZoneOffset.UTC), Duration.ZERO, history);
    }

    @AfterEach void stop() { server.stop(0); }

    @Test void updatesPriceAndMetadataOnlyOnceWithinHour() {
        var before = repository.findById("sony-wf-1000xm5").orElseThrow();
        service.refreshDuePrices();
        var updated = repository.findById(before.id()).orElseThrow();
        assertThat(updated.price()).isEqualTo(222222);
        assertThat(updated.priceFetchedAt()).isEqualTo(now);
        assertThat(updated.priceAttemptedAt()).isEqualTo(now);
        assertThat(updated.priceCheckedAt()).isEqualTo(LocalDate.of(2026, 11, 16));
        assertThat(updated.priceRefreshStatus()).isEqualTo("updated");
        assertThat(jdbc.queryForObject("SELECT count(*) FROM product_price_history WHERE product_id=?",Integer.class,before.id())).isEqualTo(1);
        assertThat(updated.specs()).isEqualTo(before.specs());
        assertThat(updated.priceComparisonUrl()).isEqualTo(before.priceComparisonUrl());
        service.refreshDuePrices();
        assertThat(requests.get()).isEqualTo(1);
    }

    @Test void failureKeepsLastGoodPriceAndDoesNotRetryImmediately() {
        service.refreshDuePrices();
        var before = repository.findById("sony-wf-1000xm5").orElseThrow();
        jdbc.update("UPDATE products SET price_attempted_at=NULL WHERE id=?", before.id());
        body = "<html>no price</html>";
        service.refreshDuePrices();
        var failed = repository.findById(before.id()).orElseThrow();
        assertThat(failed.price()).isEqualTo(before.price());
        assertThat(failed.priceFetchedAt()).isEqualTo(before.priceFetchedAt());
        assertThat(failed.priceCheckedAt()).isEqualTo(before.priceCheckedAt());
        assertThat(failed.priceRefreshStatus()).isEqualTo("failed");
        service.refreshDuePrices();
        assertThat(requests.get()).isEqualTo(2);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM product_price_history WHERE product_id=?",Integer.class,before.id())).isEqualTo(1);
    }

    @Test void blocksPauseTheWholeProviderForAnHour() {
        status = 429;
        service.refreshDuePrices();
        jdbc.update("UPDATE products SET price_attempted_at=NULL WHERE id='sony-wf-1000xm5'");
        service.refreshDuePrices();
        assertThat(requests.get()).isEqualTo(1);
        assertThat(repository.findById("sony-wf-1000xm5").orElseThrow().priceRefreshStatus()).isEqualTo("failed");
    }
    @Test void manualPriceOptOutDoesNotContactProvider() {
        jdbc.update("UPDATE products SET price_auto_refresh=FALSE WHERE id='sony-wf-1000xm5'");
        service.refreshDuePrices();
        assertThat(requests.get()).isZero();
    }

    @Test void pendingProviderResponseCannotOverwriteAnAdminEdit() {
        var client = new DanawaPriceClient(mapper) {
            @Override public int fetch(String source) {
                jdbc.update("UPDATE products SET price=111111,version=version+1,price_auto_refresh=FALSE "
                        + "WHERE id='sony-wf-1000xm5'");
                return 222222;
            }
        };
        var guarded = new PriceRefreshService(jdbc,client,true,Clock.fixed(now,ZoneOffset.UTC),Duration.ZERO,history);
        guarded.refreshDuePrices();
        var product=repository.findById("sony-wf-1000xm5").orElseThrow();
        assertThat(product.price()).isEqualTo(111111);
        assertThat(product.priceAutoRefresh()).isFalse();
        assertThat(product.priceFetchedAt()).isNull();
        assertThat(jdbc.queryForObject("SELECT count(*) FROM product_price_history WHERE product_id=?",Integer.class,product.id())).isZero();
    }

    @Test void repeatedSuccessfulObservationsKeepEqualPricePoints() {
        service.refreshDuePrices();
        jdbc.update("UPDATE products SET price_attempted_at=NULL WHERE id='sony-wf-1000xm5'");
        service.refreshDuePrices();
        assertThat(jdbc.queryForList("SELECT price FROM product_price_history WHERE product_id=? ORDER BY id",Integer.class,"sony-wf-1000xm5"))
                .containsExactly(222222,222222);
    }

}
