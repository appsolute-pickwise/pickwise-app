package com.pickwise.api;

import static org.assertj.core.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.annotation.Propagation;

@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test") @Transactional
class PriceHistoryIntegrationTest {
    @Autowired JdbcTemplate jdbc;
    @Autowired ProductCatalogRepository products;
    @Autowired PriceHistoryRepository history;
    @Autowired MockMvc mvc;
    static final String ID="sony-wf-1000xm5",URL="https://prod.danawa.com/info/?pcode=27250154";

    void point(int version,int price,String kind,String url,Instant at) {
        jdbc.update("INSERT INTO product_price_history(product_id,product_version,price,kind,source_site,source_url,"
                        + "source_key,observed_at,checked_at) VALUES (?,?,?,?,'danawa',?,?,?,?)",
                ID,version,price,kind,url,PriceHistoryRepository.sourceKey("danawa",url),Timestamp.from(at),java.sql.Date.valueOf("2026-11-01"));
    }

    @Test void separatesSourcesKindsAndPeriodsAndKeepsActualTimes() throws Exception {
        jdbc.update("DELETE FROM product_price_history WHERE product_id=?",ID);
        Instant now=Instant.now();String old="https://prod.danawa.com/info/?pcode=11111";
        point(1,200000,"automatic",URL,now.minus(10,ChronoUnit.DAYS));
        point(2,190000,"automatic",URL,now.minus(2,ChronoUnit.DAYS));
        point(3,180000,"automatic",URL,now.minusSeconds(60));
        point(4,10000,"manual",URL,now.minusSeconds(30));
        point(5,9000,"automatic",old,now.minusSeconds(10));
        point(6,1,"automatic",URL,now.plus(1,ChronoUnit.DAYS));
        var result=history.find(products.findById(ID).orElseThrow(),7,"automatic",null);
        assertThat(result.points()).extracting(PriceHistoryResponse.Point::price).containsExactly(190000,180000);
        assertThat(result.sources()).hasSize(2);
        assertThat(result.truncated()).isFalse();
        var manual=history.find(products.findById(ID).orElseThrow(),7,"manual",null);
        assertThat(manual.points()).extracting(PriceHistoryResponse.Point::price).containsExactly(10000);
        var previous=history.find(products.findById(ID).orElseThrow(),7,"automatic",PriceHistoryRepository.sourceKey("danawa",old));
        assertThat(previous.points()).extracting(PriceHistoryResponse.Point::price).containsExactly(9000);
        assertThat(history.find(products.findById(ID).orElseThrow(),30,"automatic",null).points()).hasSize(3);
        mvc.perform(get("/api/v1/products/"+ID+"/price-history").param("days","7"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.points.length()").value(2))
                .andExpect(jsonPath("$.points[0].price").value(190000))
                .andExpect(jsonPath("$.kind").value("automatic"));
    }

    @Test void emptyHistoryIsEmptyRatherThanInventingOldPrices() throws Exception {
        jdbc.update("DELETE FROM product_price_history WHERE product_id=?",ID);
        mvc.perform(get("/api/v1/products/"+ID+"/price-history"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.points").isEmpty())
                .andExpect(jsonPath("$.sources[0].current").value(true)).andExpect(jsonPath("$.total").value(0));
    }

    @Test void validatesHistoryQueryAndMissingProducts() throws Exception {
        for(String query:new String[]{"days=0","days=365","kind=all","source=bad","source="+"a".repeat(64)}) {
            mvc.perform(get("/api/v1/products/"+ID+"/price-history?"+query)).andExpect(status().isBadRequest());
        }
        mvc.perform(get("/api/v1/products/no-product/price-history")).andExpect(status().isNotFound());
    }

    @Test @Transactional(propagation=Propagation.NOT_SUPPORTED)
    void historyWriteFailureRollsBackCurrentPriceToo() {
        String id="history-atomic-"+UUID.randomUUID();
        try {
            jdbc.update("INSERT INTO products(id,brand,name,category,price,price_checked_at,price_comparison_site,price_comparison_url) "
                    + "VALUES (?,'Test','Atomic','earbuds',100000,'2026-11-01','danawa',?)",id,URL);
            jdbc.update("INSERT INTO product_price_history(product_id,product_version,price,kind,source_site,source_url,source_key,observed_at,checked_at) "
                    + "VALUES (?,1,100000,'automatic','danawa',?,?,now(),'2026-11-01')",id,URL,PriceHistoryRepository.sourceKey("danawa",URL));
            assertThatThrownBy(()->history.recordAutomatic(id,URL,0,222222,Instant.now()))
                    .isInstanceOf(org.springframework.dao.DataIntegrityViolationException.class);
            var product=products.findById(id).orElseThrow();
            assertThat(product.price()).isEqualTo(100000);
            assertThat(product.version()).isZero();
            assertThat(product.priceFetchedAt()).isNull();
        } finally { jdbc.update("DELETE FROM products WHERE id=?",id); }
    }

    @Test void capsLargeResponsesAndDeclaresTruncation() {
        jdbc.update("DELETE FROM product_price_history WHERE product_id=?",ID);
        Instant start=Instant.now().minusSeconds(4000);
        jdbc.batchUpdate("INSERT INTO product_price_history(product_id,product_version,price,kind,source_site,source_url,source_key,observed_at,checked_at) "
                + "VALUES (?,?,100000,'manual','danawa',?,?,?,'2026-11-01')",
                java.util.stream.IntStream.range(0,3001).mapToObj(i->new Object[]{ID,i,URL,
                        PriceHistoryRepository.sourceKey("danawa",URL),Timestamp.from(start.plusSeconds(i))}).toList());
        var result=history.find(products.findById(ID).orElseThrow(),7,"manual",null);
        assertThat(result.points()).hasSize(3000);
        assertThat(result.total()).isEqualTo(3001);
        assertThat(result.truncated()).isTrue();
        assertThat(result.points().getFirst().observedAt()).isAfter(start);
    }
}
