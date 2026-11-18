package com.pickwise.api;

import static org.assertj.core.api.Assertions.*;
import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.URI;
import java.net.http.HttpClient;
import java.time.Duration;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.ObjectMapper;

class DanawaPriceClientTest {
    HttpServer server;
    DanawaPriceClient client;
    AtomicInteger requests = new AtomicInteger();
    int status = 200;
    String body = html("27250154", "234810");
    long delay;
    static final String URL = "https://prod.danawa.com/info/?pcode=27250154";

    static String html(String sku, String price) {
        return "<script type='application/ld+json'>{\"@context\":\"https://schema.org\","
                + "\"@type\":\"Product\",\"sku\":\"" + sku + "\",\"offers\":{"
                + "\"@type\":\"AggregateOffer\",\"priceCurrency\":\"KRW\",\"lowPrice\":\""
                + price + "\",\"offerCount\":3}}</script>";
    }

    @BeforeEach void start() throws Exception {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/info/", exchange -> {
            requests.incrementAndGet();
            try {
                Thread.sleep(delay);
                exchange.getResponseHeaders().set("Content-Type", "text/html; charset=UTF-8");
                exchange.getResponseHeaders().set("Location", "https://example.com/");
                byte[] bytes = body.getBytes(java.nio.charset.StandardCharsets.UTF_8);
                exchange.sendResponseHeaders(status, bytes.length);
                exchange.getResponseBody().write(bytes);
            } catch (InterruptedException error) {
                Thread.currentThread().interrupt();
            } finally {
                exchange.close();
            }
        });
        server.start();
        client = new DanawaPriceClient(new ObjectMapper(), HttpClient.newHttpClient(),
                URI.create("http://127.0.0.1:" + server.getAddress().getPort()), Duration.ofSeconds(2));
    }

    @AfterEach void stop() { server.stop(0); }

    @Test void fetchesActualHttpAndChecksIdentity() throws Exception {
        assertThat(client.fetch(URL)).isEqualTo(234810);
        assertThat(requests.get()).isEqualTo(1);
        body = html("other-product", "1000");
        assertThatThrownBy(() -> client.fetch(URL)).isInstanceOf(IOException.class);
    }

    @Test void rejectsMissingInvalidAmbiguousOrForeignCurrencyPrices() {
        for (String invalid : new String[]{"0", "-1", "", "NaN", "123.45", "2147483648"}) {
            assertThatThrownBy(() -> client.parse(html("27250154", invalid), "27250154"))
                    .isInstanceOf(IOException.class);
        }
        assertThatThrownBy(() -> client.parse(body + body, "27250154")).isInstanceOf(IOException.class);
        assertThatThrownBy(() -> client.parse(body.replace("KRW", "USD"), "27250154"))
                .isInstanceOf(IOException.class);
        assertThatThrownBy(() -> client.parse("<html>captcha</html>", "27250154"))
                .isInstanceOf(IOException.class);
        assertThatThrownBy(() -> client.parse(body.replace(":3", ":0"), "27250154"))
                .isInstanceOf(IOException.class);
    }

    @Test void doesNotFollowRedirectsOrBypassBlocks() {
        for (int code : new int[]{302, 403, 429, 500}) {
            status = code;
            assertThatThrownBy(() -> client.fetch(URL)).isInstanceOf(IOException.class);
        }
        assertThat(requests.get()).isEqualTo(4);
    }

    @Test void onlyAllowsCatalogProductUrls() {
        for (String url : new String[]{"http://127.0.0.1/info/?pcode=1", "https://prod.danawa.com.evil/info/?pcode=1",
                "https://prod.danawa.com/api/test", URL + "&redirect=http://localhost", "https://prod.danawa.com/info/?pcode=0"}) {
            assertThatThrownBy(() -> client.fetch(url)).isInstanceOf(IOException.class);
        }
        assertThat(requests.get()).isZero();
    }

    @Test void timesOutInsteadOfWaitingIndefinitely() {
        delay = 200;
        client = new DanawaPriceClient(new ObjectMapper(), HttpClient.newHttpClient(),
                URI.create("http://127.0.0.1:" + server.getAddress().getPort()), Duration.ofMillis(50));
        assertThatThrownBy(() -> client.fetch(URL)).isInstanceOfAny(
                java.util.concurrent.TimeoutException.class, java.util.concurrent.ExecutionException.class);
    }
}
