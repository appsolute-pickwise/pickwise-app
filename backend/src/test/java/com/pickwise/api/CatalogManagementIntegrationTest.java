package com.pickwise.api;

import static org.assertj.core.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.node.ObjectNode;

@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test") @Transactional
class CatalogManagementIntegrationTest {
    @Autowired MockMvc mvc;
    @Autowired JdbcTemplate jdbc;
    @Autowired ObjectMapper mapper;
    @Autowired ProductCatalogRepository products;
    @Autowired AccountService accounts;

    String account(boolean admin) throws Exception {
        String email=UUID.randomUUID()+"@example.test";
        var response=mvc.perform(post("/api/v1/auth/register").contentType("application/json")
                .content("{\"email\":\""+email+"\",\"password\":\"abcdefgh\"}"))
                .andExpect(status().isCreated()).andReturn();
        if (admin) jdbc.update("UPDATE app_users SET is_admin=TRUE WHERE email=?",email);
        return "Bearer "+mapper.readTree(response.getResponse().getContentAsString()).path("accessToken").asText();
    }

    ObjectNode input(String id) {
        ObjectNode body=(ObjectNode)mapper.readTree(mapper.writeValueAsString(products.findById("sony-wf-1000xm5").orElseThrow()));
        body.remove("priceFetchedAt");body.remove("priceAttemptedAt");body.remove("priceRefreshStatus");
        body.put("id",id);body.put("priceAutoRefresh",false);
        return body;
    }

    JsonNode create(String auth, ObjectNode body) throws Exception {
        return mapper.readTree(mvc.perform(post("/api/v1/admin/products").header("Authorization",auth)
                .contentType("application/json").content(body.toString())).andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString());
    }

    @Test void requiresServerSideAdminAndRevocationTakesEffectImmediately() throws Exception {
        String regular=account(false),admin=account(true);
        String url="/api/v1/admin/products/sony-wf-1000xm5";
        mvc.perform(get(url)).andExpect(status().isUnauthorized());
        mvc.perform(get(url).header("Authorization",regular)).andExpect(status().isForbidden());
        mvc.perform(post("/api/v1/admin/products").header("Authorization",regular)
                .contentType("application/json").content(input("forbidden-product").toString()))
                .andExpect(status().isForbidden());
        mvc.perform(get("/api/v1/auth/me").header("Authorization",regular)).andExpect(jsonPath("$.admin").value(false));
        mvc.perform(get("/api/v1/auth/me").header("Authorization",admin)).andExpect(jsonPath("$.admin").value(true));
        mvc.perform(get(url).header("Authorization",admin)).andExpect(status().isOk());
        jdbc.update("UPDATE app_users SET is_admin=FALSE WHERE is_admin=TRUE");
        mvc.perform(put(url).header("Authorization",admin).contentType("application/json")
                .content(input("sony-wf-1000xm5").toString())).andExpect(status().isForbidden());
        mvc.perform(get(url+"/changes").header("Authorization",regular)).andExpect(status().isForbidden());
        assertThat(products.findById("forbidden-product")).isEmpty();
    }

    @Test void createsEditsAndRecordsChangesWithoutReplacingOtherProducts() throws Exception {
        String auth=account(true),id="catalog-test-"+UUID.randomUUID();
        var body=input(id);long count=products.count();
        var created=create(auth,body);
        assertThat(created.path("version").asInt()).isZero();
        assertThat(products.count()).isEqualTo(count+1);
        mvc.perform(get("/api/v1/products/"+id)).andExpect(status().isOk())
                .andExpect(jsonPath("$.specs[?(@.key=='anc')].value").value(true));
        body.put("name","수정한 제품");body.put("price",123456);body.put("priceCheckedAt","2026-11-01");
        mvc.perform(put("/api/v1/admin/products/"+id).header("Authorization",auth)
                .contentType("application/json").content(body.toString())).andExpect(status().isOk())
                .andExpect(jsonPath("$.version").value(1)).andExpect(jsonPath("$.price").value(123456))
                .andExpect(jsonPath("$.priceRefreshStatus").value("manual"));
        mvc.perform(get("/api/v1/admin/products/"+id+"/changes").header("Authorization",auth))
                .andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].before.price").value(234710))
                .andExpect(jsonPath("$[0].after.price").value(123456));
        assertThat(products.findById("sony-wf-1000xm5").orElseThrow().price()).isEqualTo(234710);
    }

    @Test void refusesStaleEditsAndDuplicateIdsWithoutPartialWrites() throws Exception {
        String auth=account(true),id="catalog-test-"+UUID.randomUUID();
        var body=input(id);create(auth,body);
        mvc.perform(post("/api/v1/admin/products").header("Authorization",auth).contentType("application/json")
                .content(body.toString())).andExpect(status().isConflict());
        jdbc.update("UPDATE products SET version=version+1,price=555555 WHERE id=?",id);
        body.put("price",111111);
        mvc.perform(put("/api/v1/admin/products/"+id).header("Authorization",auth)
                .contentType("application/json").content(body.toString())).andExpect(status().isConflict());
        assertThat(products.findById(id).orElseThrow().price()).isEqualTo(555555);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM product_changes WHERE product_id=?",Integer.class,id)).isEqualTo(1);
    }

    @Test void validatesPriceSourcesSpecTypesAndProvenance() throws Exception {
        String auth=account(true),id="catalog-invalid";long count=products.count();
        for (String change:new String[]{"zero","future","url","duplicate-spec","anc","battery","source-date","image","unsupported-auto"}) {
            var body=input(id);
            switch(change) {
                case "zero" -> body.put("price",0);
                case "future" -> body.put("priceCheckedAt","2099-01-01");
                case "url" -> body.put("priceComparisonUrl","https://prod.danawa.com.evil/info/?pcode=1");
                case "duplicate-spec" -> ((tools.jackson.databind.node.ArrayNode)body.path("specs")).add(body.path("specs").get(0));
                case "anc" -> {for(var s:body.path("specs")) if(s.path("key").asText().equals("anc")) ((ObjectNode)s).put("value","true");}
                case "battery" -> {for(var s:body.path("specs")) if(s.path("key").asText().equals("weight")) ((ObjectNode)s).put("unit","kg");}
                case "source-date" -> ((ObjectNode)body.path("specs").get(0)).putNull("checkedAt");
                case "image" -> body.put("imageAsset","assets/images/products/../../secret.png");
                case "unsupported-auto" -> {body.put("priceComparisonSite","naver");body.put("priceComparisonUrl","https://search.shopping.naver.com/search/all?query=test");body.put("priceAutoRefresh",true);}
            }
            mvc.perform(post("/api/v1/admin/products").header("Authorization",auth).contentType("application/json")
                    .content(body.toString())).andExpect(status().isBadRequest());
        }
        assertThat(products.count()).isEqualTo(count);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM product_changes WHERE product_id=?",Integer.class,id)).isZero();
    }

    @Test void changingCurrentProductKeepsPreviouslySavedSnapshot() throws Exception {
        String auth=account(true);
        var saved=mvc.perform(post("/api/v1/me/comparisons").header("Authorization",auth).contentType("application/json")
                .content("{\"title\":\"기존 판단\",\"productIds\":[\"sony-wf-1000xm5\"],\"preferences\":{},\"version\":0}"))
                .andExpect(status().isCreated()).andReturn();
        String record=mapper.readTree(saved.getResponse().getContentAsString()).path("id").asText();
        String before=jdbc.queryForObject("SELECT snapshot FROM comparisons WHERE id=?",String.class,record);
        var body=input("sony-wf-1000xm5");body.put("price",111111);
        mvc.perform(put("/api/v1/admin/products/sony-wf-1000xm5").header("Authorization",auth)
                .contentType("application/json").content(body.toString())).andExpect(status().isOk());
        assertThat(jdbc.queryForObject("SELECT snapshot FROM comparisons WHERE id=?",String.class,record)).isEqualTo(before);
    }
    @Test
    @Transactional(propagation=org.springframework.transaction.annotation.Propagation.NOT_SUPPORTED)
    void concurrentEditorsCannotSilentlyOverwriteEachOther() throws Exception {
        String auth=account(true),id="concurrent-test-"+UUID.randomUUID();
        String owner=accounts.authenticate(auth).toString();
        try {
            var initial=input(id);create(auth,initial);
            var first=input(id);first.put("price",111111);
            var second=input(id);second.put("price",222222);
            var ready=new java.util.concurrent.CountDownLatch(2);
            var go=new java.util.concurrent.CountDownLatch(1);
            try(var executor=java.util.concurrent.Executors.newVirtualThreadPerTaskExecutor()) {
                java.util.List<java.util.concurrent.Future<Integer>> attempts=new java.util.ArrayList<>();
                for(var body:java.util.List.of(first,second)) {
                    attempts.add(executor.submit(()->{
                        ready.countDown();
                        if(!go.await(5,java.util.concurrent.TimeUnit.SECONDS)) throw new IllegalStateException("Start timeout");
                        return mvc.perform(put("/api/v1/admin/products/"+id).header("Authorization",auth)
                                .contentType("application/json").content(body.toString()))
                                .andReturn().getResponse().getStatus();
                    }));
                }
                assertThat(ready.await(5,java.util.concurrent.TimeUnit.SECONDS)).isTrue();go.countDown();
                var statuses=new java.util.ArrayList<Integer>();
                for(var attempt:attempts) statuses.add(attempt.get(15,java.util.concurrent.TimeUnit.SECONDS));
                assertThat(statuses).containsExactlyInAnyOrder(200,409);
            }
            assertThat(products.findById(id).orElseThrow().version()).isEqualTo(1);
            assertThat(jdbc.queryForObject("SELECT count(*) FROM product_changes WHERE product_id=?",Integer.class,id)).isEqualTo(2);
        } finally {
            jdbc.update("DELETE FROM product_changes WHERE product_id=?",id);
            jdbc.update("DELETE FROM products WHERE id=?",id);
            jdbc.update("DELETE FROM app_users WHERE id=?",owner);
        }
    }

    @Test void nameOnlyEditDoesNotAddAnInventedPriceObservation() throws Exception {
        String auth=account(true),id="history-name-"+UUID.randomUUID();
        var body=input(id);create(auth,body);
        body.put("name","이름만 수정");
        mvc.perform(put("/api/v1/admin/products/"+id).header("Authorization",auth)
                .contentType("application/json").content(body.toString())).andExpect(status().isOk());
        assertThat(jdbc.queryForObject("SELECT count(*) FROM product_price_history WHERE product_id=?",Integer.class,id)).isEqualTo(1);
        body.put("version",1);body.put("price",111111);
        mvc.perform(put("/api/v1/admin/products/"+id).header("Authorization",auth)
                .contentType("application/json").content(body.toString())).andExpect(status().isOk());
        assertThat(jdbc.queryForObject("SELECT count(*) FROM product_price_history WHERE product_id=? AND kind='manual'",Integer.class,id)).isEqualTo(2);
    }

}
