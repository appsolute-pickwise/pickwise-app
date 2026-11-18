package com.pickwise.api;

import java.util.*;
import java.time.Instant;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

@Service
public class WatchService {
    private final JdbcTemplate jdbc;
    private final AccountService accounts;
    private final ProductCatalogRepository products;
    public WatchService(JdbcTemplate jdbc,AccountService accounts,ProductCatalogRepository products) {
        this.jdbc=jdbc;this.accounts=accounts;this.products=products;
    }
    public List<Map<String,Object>> list(String header) {
        var owner=accounts.authenticate(header);
        return jdbc.query("SELECT w.*,p.name,p.price,p.price_fetched_at,p.price_comparison_site,p.price_comparison_url FROM product_watches w JOIN products p ON p.id=w.product_id WHERE w.user_id=? ORDER BY w.updated_at DESC,w.id",
                (rs,n)->{var row=new LinkedHashMap<String,Object>();
                    row.put("productId",rs.getString("product_id"));row.put("name",rs.getString("name"));row.put("price",rs.getInt("price"));
                    row.put("targetPrice",rs.getObject("target_price"));row.put("version",rs.getInt("version"));row.put("armed",rs.getBoolean("armed"));
                    row.put("sourceChanged",!rs.getString("source_key").equals(PriceHistoryRepository.sourceKey(rs.getString("price_comparison_site"),rs.getString("price_comparison_url"))));
                    row.put("priceFetchedAt",rs.getTimestamp("price_fetched_at")==null?null:rs.getTimestamp("price_fetched_at").toInstant().toString());return row;
                },owner.toString());
    }
    @Transactional(isolation=Isolation.READ_COMMITTED)
    public void save(String header,String id,Integer target,int version) {
        var owner=accounts.authenticate(header);
        if(jdbc.queryForList("SELECT id FROM products WHERE id=? FOR UPDATE",id).isEmpty()) throw new ResponseStatusException(HttpStatus.NOT_FOUND);
        jdbc.queryForList("SELECT id FROM app_users WHERE id=? FOR UPDATE",owner.toString());accounts.authenticate(header);
        var p=products.findById(id).orElseThrow();
        var existing=jdbc.queryForList("SELECT version FROM product_watches WHERE user_id=? AND product_id=? FOR UPDATE",owner.toString(),id);
        String key=PriceHistoryRepository.sourceKey(p.priceComparisonSite(),p.priceComparisonUrl());
        if(existing.isEmpty()) {
            if(version!=0) throw new ResponseStatusException(HttpStatus.CONFLICT);
            if(jdbc.queryForObject("SELECT count(*) FROM product_watches WHERE user_id=?",Integer.class,owner.toString())>=100) throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"관심 제품은 최대 100개입니다.");
            jdbc.update("INSERT INTO product_watches(id,user_id,product_id,target_price,source_key,armed) VALUES (?,?,?,?,?,?)",UUID.randomUUID().toString(),owner.toString(),id,target,key,target!=null);
        } else {
            int changed=jdbc.update("UPDATE product_watches SET target_price=?,source_key=?,armed=?,version=version+1,updated_at=CURRENT_TIMESTAMP(6) WHERE user_id=? AND product_id=? AND version=?",target,key,target!=null,owner.toString(),id,version);
            if(changed!=1) throw new ResponseStatusException(HttpStatus.CONFLICT);
        }
    }
    @Transactional
    public void remove(String header,String id) {
        var owner=accounts.authenticate(header);
        // 수집 작업과 같은 제품→관심 설정 순서로 잠가 삭제와 알림 생성의 교착을 피한다.
        jdbc.queryForList("SELECT id FROM products WHERE id=? FOR UPDATE",id);
        if(jdbc.update("DELETE FROM product_watches WHERE user_id=? AND product_id=?",owner.toString(),id)==0) throw new ResponseStatusException(HttpStatus.NOT_FOUND);
    }
    @Transactional(propagation=Propagation.MANDATORY)
    public void evaluate(String id,Instant at) {
        var p=products.findById(id).orElseThrow();
        String source=PriceHistoryRepository.sourceKey(p.priceComparisonSite(),p.priceComparisonUrl());
        var rules=jdbc.queryForList("SELECT * FROM product_watches WHERE product_id=? AND armed=TRUE AND target_price>=? AND source_key=? AND updated_at<=? FOR UPDATE",id,p.price(),source,java.sql.Timestamp.from(at));
        for(var rule:rules) {
            jdbc.update("INSERT INTO price_alerts(id,user_id,watch_id,rule_version,product_id,product_name,price,target_price,source_url,observed_at) VALUES (?,?,?,?,?,?,?,?,?,?)",
                    UUID.randomUUID().toString(),rule.get("user_id"),rule.get("id"),rule.get("version"),id,p.name(),p.price(),rule.get("target_price"),p.priceComparisonUrl(),java.sql.Timestamp.from(at));
            jdbc.update("UPDATE product_watches SET armed=FALSE WHERE id=?",rule.get("id"));
        }
    }
    public List<Map<String,Object>> alerts(String header) {
        var owner=accounts.authenticate(header);
        return jdbc.query("SELECT * FROM price_alerts WHERE user_id=? ORDER BY observed_at DESC,id LIMIT 100",(rs,n)->Map.<String,Object>of(
                "id",rs.getString("id"),"productId",rs.getString("product_id"),"name",rs.getString("product_name"),"price",rs.getInt("price"),
                "targetPrice",rs.getInt("target_price"),"sourceUrl",rs.getString("source_url"),"observedAt",rs.getTimestamp("observed_at").toInstant().toString(),"read",rs.getTimestamp("read_at")!=null),owner.toString());
    }
    public void markRead(String header,UUID id) {
        var owner=accounts.authenticate(header);
        if(jdbc.update("UPDATE price_alerts SET read_at=COALESCE(read_at,now()) WHERE id=? AND user_id=?",id.toString(),owner.toString())!=1) {
            if(jdbc.queryForObject("SELECT count(*) FROM price_alerts WHERE id=? AND user_id=?",Integer.class,id.toString(),owner.toString())==0) throw new ResponseStatusException(HttpStatus.NOT_FOUND);
        }
    }
}
