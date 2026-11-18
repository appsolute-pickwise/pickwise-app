package com.pickwise.api;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HexFormat;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.web.server.ResponseStatusException;

@Repository
public class PriceHistoryRepository {
    private static final int MAX_POINTS = 3000;
    private final JdbcTemplate jdbc;
    private final WatchService watches;

    public PriceHistoryRepository(JdbcTemplate jdbc, WatchService watches) { this.jdbc = jdbc; this.watches=watches; }

    @Transactional
    public boolean recordAutomatic(String id, String url, int version, int price, Instant received) {
        int changed = jdbc.update("UPDATE products SET price=?,price_checked_at=?,price_fetched_at=?,"
                        + "price_refresh_status='updated',version=version+1,updated_at=? "
                        + "WHERE id=? AND price_comparison_url=? AND version=? AND price_auto_refresh=TRUE",
                price,java.sql.Date.valueOf(received.atZone(ZoneId.of("Asia/Seoul")).toLocalDate()),
                Timestamp.from(received),Timestamp.from(received),id,url,version);
        if (changed == 0) return false;
        jdbc.update("INSERT INTO product_price_history(product_id,product_version,price,kind,source_site,source_url,"
                        + "source_key,observed_at,checked_at) SELECT id,version,price,'automatic',price_comparison_site,"
                        + "price_comparison_url,SHA2(CONCAT(price_comparison_site,CHAR(10),price_comparison_url),256),"
                        + "price_fetched_at,price_checked_at FROM products WHERE id=?",id);
        watches.evaluate(id,received);
        return true;
    }

    @Transactional(propagation = Propagation.MANDATORY)
    public void recordManual(ProductResponse product) {
        jdbc.update("INSERT INTO product_price_history(product_id,product_version,price,kind,source_site,source_url,"
                        + "source_key,observed_at,checked_at) VALUES (?,?,?,'manual',?,?,?,?,?)",
                product.id(),product.version(),product.price(),product.priceComparisonSite(),product.priceComparisonUrl(),
                sourceKey(product.priceComparisonSite(),product.priceComparisonUrl()),Timestamp.from(Instant.now()),
                java.sql.Date.valueOf(product.priceCheckedAt()));
    }

    @Transactional(readOnly = true)
    public PriceHistoryResponse find(ProductResponse product, int days, String kind, String requestedSource) {
        Instant now = Instant.now();
        Timestamp from = Timestamp.from(now.minus(days,ChronoUnit.DAYS)), to = Timestamp.from(now);
        String currentKey = sourceKey(product.priceComparisonSite(),product.priceComparisonUrl());
        List<PriceHistoryResponse.Source> observed = jdbc.query(
                "SELECT source_key,source_site,source_url,count(*) AS total FROM product_price_history "
                        + "WHERE product_id=? AND kind=? AND observed_at>=? AND observed_at<=? "
                        + "GROUP BY source_key,source_site,source_url ORDER BY source_key",
                (rs,n) -> new PriceHistoryResponse.Source(rs.getString(1),rs.getString(2),rs.getString(3),
                        currentKey.equals(rs.getString(1)),rs.getLong(4)),product.id(),kind,from,to);
        var sources = new ArrayList<PriceHistoryResponse.Source>();
        sources.add(observed.stream().filter(PriceHistoryResponse.Source::current).findFirst()
                .orElse(new PriceHistoryResponse.Source(currentKey,product.priceComparisonSite(),product.priceComparisonUrl(),true,0)));
        observed.stream().filter(source -> !source.current()).forEach(sources::add);
        String selected = requestedSource == null ? currentKey : requestedSource;
        var selectedSource = sources.stream().filter(source -> source.key().equals(selected)).findFirst()
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST,"해당 기간의 출처를 찾을 수 없습니다."));
        var points = new ArrayList<>(jdbc.query("SELECT id,price,observed_at,checked_at FROM product_price_history "
                        + "WHERE product_id=? AND kind=? AND source_key=? AND observed_at>=? AND observed_at<=? "
                        + "ORDER BY observed_at DESC,id DESC LIMIT ?",
                (rs,n) -> new PriceHistoryResponse.Point(rs.getLong(1),rs.getInt(2),rs.getTimestamp(3).toInstant(),
                        rs.getDate(4).toLocalDate()),product.id(),kind,selected,from,to,MAX_POINTS));
        Collections.reverse(points);
        return new PriceHistoryResponse(product.id(),days,kind,now,selected,List.copyOf(sources),List.copyOf(points),
                selectedSource.count(),selectedSource.count()>points.size());
    }

    static String sourceKey(String site, String url) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest((site+"\n"+url).getBytes(StandardCharsets.UTF_8)));
        } catch (java.security.NoSuchAlgorithmException error) { throw new IllegalStateException(error); }
    }
}
