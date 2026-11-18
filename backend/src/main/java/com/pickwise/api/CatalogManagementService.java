package com.pickwise.api;

import java.net.URI;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import tools.jackson.databind.ObjectMapper;
import static com.pickwise.api.AdminProductController.Input;

@Service
public class CatalogManagementService {
    private final JdbcTemplate jdbc;
    private final AccountService accounts;
    private final ProductCatalogRepository products;
    private final ObjectMapper mapper;
    private final DanawaPriceClient priceClient;
    private final PriceHistoryRepository history;

    public CatalogManagementService(JdbcTemplate jdbc, AccountService accounts,
            ProductCatalogRepository products, ObjectMapper mapper, DanawaPriceClient priceClient, PriceHistoryRepository history) {
        this.jdbc=jdbc; this.accounts=accounts; this.products=products; this.mapper=mapper; this.priceClient=priceClient; this.history=history;
    }

    private UUID requireAdmin(String header, boolean lock) {
        UUID id = accounts.authenticate(header);
        var rows = jdbc.queryForList("SELECT is_admin FROM app_users WHERE id=?" + (lock ? " FOR UPDATE" : ""),
                Boolean.class, id.toString());
        if (rows.isEmpty() || !rows.getFirst()) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "관리자 권한이 필요합니다.");
        }
        if (lock) accounts.authenticate(header);
        return id;
    }

    public ProductResponse detail(String header, String id) {
        requireAdmin(header, false);
        return product(id);
    }

    @Transactional(isolation = org.springframework.transaction.annotation.Isolation.READ_COMMITTED)
    public ProductResponse create(String header, Input input) {
        UUID actor = requireAdmin(header, true);
        validate(input);
        if (input.version() != 0) bad();
        try {
            jdbc.update("INSERT INTO products(id,brand,name,category,image_asset,price,price_checked_at,"
                            + "price_comparison_site,price_comparison_url,price_auto_refresh,price_attempted_at) "
                            + "VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                    input.id(),input.brand().trim(),input.name().trim(),input.category(),blank(input.imageAsset()),
                    input.price(),java.sql.Date.valueOf(input.priceCheckedAt()),input.priceComparisonSite(),
                    input.priceComparisonUrl(),input.priceAutoRefresh(),Timestamp.from(Instant.now()));
        } catch (DuplicateKeyException error) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "이미 등록된 제품 ID입니다.");
        }
        replaceDetails(input);
        ProductResponse created = product(input.id());
        history.recordManual(created);
        audit(actor, "CREATE", null, created);
        return created;
    }

    @Transactional(isolation = org.springframework.transaction.annotation.Isolation.READ_COMMITTED)
    public ProductResponse update(String header, String id, Input input) {
        UUID actor = requireAdmin(header, true);
        validate(input);
        if (!id.equals(input.id())) bad();
        var locked = jdbc.queryForList("SELECT id FROM products WHERE id=? FOR UPDATE",String.class,id);
        if (locked.isEmpty()) throw new ResponseStatusException(HttpStatus.NOT_FOUND);
        ProductResponse before = product(id);
        if (before.version() != input.version()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "제품 정보가 변경됐습니다. 다시 불러와주세요.");
        }
        boolean priceChanged = before.price()!=input.price() || !before.priceCheckedAt().equals(input.priceCheckedAt())
                || !before.priceComparisonUrl().equals(input.priceComparisonUrl())
                || !before.priceComparisonSite().equals(input.priceComparisonSite());
        int changed = jdbc.update("UPDATE products SET brand=?,name=?,category=?,image_asset=?,price=?,price_checked_at=?,"
                        + "price_comparison_site=?,price_comparison_url=?,price_auto_refresh=?,version=version+1,"
                        + "price_fetched_at=IF(?,NULL,price_fetched_at),"
                        + "price_attempted_at=IF(?,?,price_attempted_at),"
                        + "price_refresh_status=IF(?,'manual',price_refresh_status),updated_at=? WHERE id=? AND version=?",
                input.brand().trim(),input.name().trim(),input.category(),blank(input.imageAsset()),input.price(),
                java.sql.Date.valueOf(input.priceCheckedAt()),input.priceComparisonSite(),input.priceComparisonUrl(),
                input.priceAutoRefresh(),priceChanged,priceChanged,Timestamp.from(Instant.now()),priceChanged,
                Timestamp.from(Instant.now()),id,input.version());
        if (changed != 1) throw new ResponseStatusException(HttpStatus.CONFLICT, "제품 정보가 변경됐습니다.");
        replaceDetails(input);
        ProductResponse after = product(id);
        if (priceChanged) history.recordManual(after);
        audit(actor, "UPDATE", before, after);
        return after;
    }

    public List<Map<String,Object>> changes(String header, String id) {
        requireAdmin(header, false);
        product(id);
        return jdbc.query("SELECT id,action,changed_at,before_json,after_json FROM product_changes "
                        + "WHERE product_id=? ORDER BY id DESC LIMIT 20",
                (rs,n) -> Map.<String,Object>of("id",rs.getLong("id"),"action",rs.getString("action"),
                        "changedAt",rs.getTimestamp("changed_at").toInstant().toString(),
                        "before",rs.getString("before_json")==null ? mapper.nullNode() : mapper.readTree(rs.getString("before_json")),
                        "after",mapper.readTree(rs.getString("after_json"))),id);
    }

    private ProductResponse product(String id) {
        return products.findById(id).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND));
    }

    private void replaceDetails(Input input) {
        jdbc.update("DELETE FROM product_tags WHERE product_id=?",input.id());
        jdbc.update("DELETE FROM product_specifications WHERE product_id=?",input.id());
        for (int i=0;i<input.tags().size();i++) {
            jdbc.update("INSERT INTO product_tags(product_id,position,tag) VALUES (?,?,?)",input.id(),i,input.tags().get(i).trim());
        }
        for (int i=0;i<input.specs().size();i++) {
            var s=input.specs().get(i);
            jdbc.update("INSERT INTO product_specifications(product_id,position,`key`,label,value_json,unit,source_url,checked_at) "
                            + "VALUES (?,?,?,?,?,?,?,?)",input.id(),i,s.key(),s.label().trim(),mapper.writeValueAsString(s.value()),
                    blank(s.unit()),blank(s.sourceUrl()),s.checkedAt()==null ? null : java.sql.Date.valueOf(s.checkedAt()));
        }
    }

    private void audit(UUID actor, String action, ProductResponse before, ProductResponse after) {
        jdbc.update("INSERT INTO product_changes(product_id,actor_id,action,before_json,after_json) VALUES (?,?,?,?,?)",
                after.id(),actor.toString(),action,before==null ? null : mapper.writeValueAsString(before),mapper.writeValueAsString(after));
    }

    private void validate(Input input) {
        LocalDate today=LocalDate.now(ZoneId.of("Asia/Seoul"));
        if (input.priceCheckedAt().isAfter(today)) bad();
        URI source=https(input.priceComparisonUrl());
        var hosts=switch(input.priceComparisonSite()) {
            case "danawa" -> List.of("prod.danawa.com");
            case "enuri" -> List.of("www.enuri.com","enuri.com");
            case "naver" -> List.of("search.shopping.naver.com","shopping.naver.com","smartstore.naver.com","brand.naver.com");
            default -> List.<String>of();
        };
        if (!hosts.contains(source.getHost())) bad();
        if (input.priceComparisonSite().equals("danawa") && !priceClient.supports(input.priceComparisonUrl())) bad();
        if (input.priceAutoRefresh() && !input.priceComparisonSite().equals("danawa")) bad();
        if (blank(input.imageAsset())!=null && !input.imageAsset().matches("assets/images/products/[a-zA-Z0-9_/-]+\\.(png|jpg|jpeg|webp)")) bad();
        var tags=new HashSet<String>();
        for (String tag:input.tags()) if (!tags.add(tag.trim())) bad();
        var keys=new HashSet<String>();
        for (var spec:input.specs()) {
            if (!keys.add(spec.key())) bad();
            var value=spec.value();
            if (!(value.isTextual() || value.isNumber() || value.isBoolean())) bad();
            if (value.isTextual() && (value.asText().isBlank() || value.asText().length()>500)) bad();
            if (value.isNumber() && !Double.isFinite(value.asDouble())) bad();
            if (List.of("batteryHours","batteryHoursAncOn","maxBatteryHours","maxBatteryHoursAncOn","weight").contains(spec.key())) {
                if (!value.isNumber() || value.asDouble()<=0 || value.asDouble()>1000) bad();
                if (!Objects.equals(spec.unit(),spec.key().equals("weight")?"g":"시간")) bad();
            }
            if (List.of("anc","earHook").contains(spec.key()) && !value.isBoolean()) bad();
            if (spec.key().equals("wearType") && !value.isTextual()) bad();
            if (blank(spec.sourceUrl())!=null) https(spec.sourceUrl());
            if ((blank(spec.sourceUrl())==null)!=(spec.checkedAt()==null)) bad();
            if (spec.checkedAt()!=null && spec.checkedAt().isAfter(today)) bad();
        }
    }

    private URI https(String value) {
        try {
            URI uri=URI.create(value);
            if (!"https".equals(uri.getScheme()) || uri.getHost()==null || uri.getUserInfo()!=null
                    || uri.getFragment()!=null || (uri.getPort()!=-1 && uri.getPort()!=443)) bad();
            return uri;
        } catch (IllegalArgumentException error) { throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"출처 URL을 확인해주세요."); }
    }

    private static String blank(String value) { return value==null || value.isBlank() ? null : value.trim(); }
    private static void bad() { throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"상품 입력값을 확인해주세요."); }
}
