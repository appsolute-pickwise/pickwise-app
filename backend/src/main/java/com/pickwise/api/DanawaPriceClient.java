package com.pickwise.api;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;
import java.util.regex.Pattern;
import org.springframework.stereotype.Component;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

@Component
public class DanawaPriceClient {
    private static final Pattern SOURCE = Pattern.compile(
            "https://prod\\.danawa\\.com/info/\\?pcode=([1-9][0-9]{0,11})");
    private static final Pattern SCRIPT = Pattern.compile(
            "<script\\b([^>]*)>(.*?)</script\\s*>", Pattern.CASE_INSENSITIVE | Pattern.DOTALL);
    private static final Pattern JSON_LD = Pattern.compile(
            "\\btype\\s*=\\s*['\"]application/ld\\+json['\"]", Pattern.CASE_INSENSITIVE);
    private final ObjectMapper mapper;
    private final HttpClient http;
    private final URI testOrigin;
    private final Duration timeout;

    @org.springframework.beans.factory.annotation.Autowired
    public DanawaPriceClient(ObjectMapper mapper) {
        this(mapper, HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5))
                .followRedirects(HttpClient.Redirect.NEVER).build(), null, Duration.ofSeconds(12));
    }

    DanawaPriceClient(ObjectMapper mapper, HttpClient http, URI testOrigin, Duration timeout) {
        this.mapper = mapper;
        this.http = http;
        this.testOrigin = testOrigin;
        this.timeout = timeout;
    }

    public boolean supports(String url) {
        return url != null && SOURCE.matcher(url).matches();
    }

    public int fetch(String sourceUrl) throws Exception {
        var source = SOURCE.matcher(sourceUrl);
        if (!source.matches()) throw new IOException("Unsupported price source");
        URI uri = URI.create(sourceUrl);
        if (testOrigin != null) uri = testOrigin.resolve(uri.getRawPath() + "?" + uri.getRawQuery());
        var request = HttpRequest.newBuilder(uri).timeout(timeout)
                .header("User-Agent", "PickWisePriceCheck/1.0")
                .header("Accept", "text/html").GET().build();
        var pending = http.sendAsync(request, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
        HttpResponse<String> response;
        try {
            response = pending.get(timeout.toMillis(), TimeUnit.MILLISECONDS);
        } finally {
            if (!pending.isDone()) pending.cancel(true);
        }
        if (response.statusCode() == 403 || response.statusCode() == 429) {
            throw new RateLimitedException();
        }
        if (response.statusCode() != 200) throw new IOException("Price provider HTTP error");
        if (!response.headers().firstValue("Content-Type").orElse("").contains("text/html")
                || response.body().length() > 4_000_000) throw new IOException("Invalid price page");
        return parse(response.body(), source.group(1));
    }

    int parse(String html, String productCode) throws IOException {
        var scripts = SCRIPT.matcher(html);
        List<JsonNode> products = new ArrayList<>();
        while (scripts.find()) {
            if (!JSON_LD.matcher(scripts.group(1)).find()) continue;
            try {
                collect(mapper.readTree(scripts.group(2)), productCode, products);
            } catch (RuntimeException error) {
                throw new IOException("Invalid price JSON", error);
            }
        }
        if (products.size() != 1) throw new IOException("Product identity missing or ambiguous");
        var offers = products.getFirst().path("offers");
        if (!offers.path("@type").asText().equals("AggregateOffer")
                || !offers.path("priceCurrency").asText().equals("KRW")
                || (offers.has("offerCount") && offers.path("offerCount").asInt() <= 0)) {
            throw new IOException("No KRW price offer");
        }
        try {
            int price = new java.math.BigDecimal(offers.path("lowPrice").asText()).intValueExact();
            if (price <= 0) throw new ArithmeticException("Non-positive price");
            return price;
        } catch (IllegalArgumentException | ArithmeticException error) {
            throw new IOException("Invalid price value", error);
        }
    }

    private void collect(JsonNode node, String productCode, List<JsonNode> products) {
        if (node == null) return;
        if (node.isArray()) {
            node.forEach(child -> collect(child, productCode, products));
        } else if (node.isObject()) {
            if (node.path("@type").asText().equals("Product")
                    && node.path("sku").asText().equals(productCode)) products.add(node);
            if (node.has("@graph")) collect(node.path("@graph"), productCode, products);
        }
    }

    static class RateLimitedException extends IOException {}
}
