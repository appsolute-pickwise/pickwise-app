package com.pickwise.api;

import static org.assertj.core.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import java.util.*;
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

@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test") @Transactional
class AccountDeletionIntegrationTest {
    @Autowired MockMvc mvc;
    @Autowired JdbcTemplate jdbc;
    @Autowired ObjectMapper mapper;
    @Autowired AccountService accounts;
    @Autowired WatchService watches;
    @Autowired PushDeliveryService delivery;
    static final String PRODUCT="sony-wf-1000xm5";
    String email(){return UUID.randomUUID()+"@example.test";}
    JsonNode session(String email,boolean register) throws Exception {
        return mapper.readTree(mvc.perform(post("/api/v1/auth/"+(register?"register":"login"))
                .contentType("application/json").content("{\"email\":\""+email+"\",\"password\":\"abcdefgh\"}"))
                .andExpect(register?status().isCreated():status().isOk()).andReturn().getResponse().getContentAsString());
    }
    String auth(JsonNode session){return "Bearer "+session.path("accessToken").asText();}
    int count(String table,String owner){return jdbc.queryForObject("SELECT count(*) FROM "+table+" WHERE user_id=?",Integer.class,owner);}

    @Test void passwordAndAuthenticationAreRequiredWithoutDeletingAnything() throws Exception {
        String token=auth(session(email(),true)),owner=accounts.authenticate(token).toString();
        mvc.perform(delete("/api/v1/me/account").contentType("application/json").content("{\"currentPassword\":\"abcdefgh\"}"))
                .andExpect(status().isUnauthorized());
        mvc.perform(delete("/api/v1/me/account").header("Authorization",token).contentType("application/json").content("{\"currentPassword\":\"short\"}"))
                .andExpect(status().isBadRequest());
        mvc.perform(delete("/api/v1/me/account").header("Authorization",token).contentType("application/json").content("{\"currentPassword\":\"incorrect\"}"))
                .andExpect(status().isUnprocessableEntity());
        assertThat(count("auth_sessions",owner)).isEqualTo(1);
        mvc.perform(get("/api/v1/auth/me").header("Authorization",token)).andExpect(status().isOk());
    }

    @Test void deletesOnlyOwnDataAndAllSessionsAndAllowsFreshRegistration() throws Exception {
        String email=email();var first=session(email,true);var second=session(email,false);
        String token=auth(first),owner=accounts.authenticate(token).toString(),other=auth(session(email(),true));
        String otherId=accounts.authenticate(other).toString();
        jdbc.update("INSERT INTO user_preferences(user_id,preferences) VALUES (?,'{}')",owner);
        jdbc.update("INSERT INTO comparisons(id,user_id,title,product_ids,preferences) VALUES (?,?,'Saved','[]','{}')",UUID.randomUUID().toString(),owner);
        watches.save(token,PRODUCT,999999,0);watches.save(other,PRODUCT,null,0);
        String alert=UUID.randomUUID().toString();
        jdbc.update("INSERT INTO price_alerts(id,user_id,watch_id,rule_version,product_id,product_name,price,target_price,source_url,observed_at) SELECT ?,user_id,id,version,product_id,'Test',1,999999,'https://example.test',now() FROM product_watches WHERE user_id=?",alert,owner);
        String fid="delete-test-"+UUID.randomUUID();delivery.register(token,fid,"android");
        jdbc.update("INSERT INTO alert_deliveries(alert_id,token_hash) SELECT ?,token_hash FROM push_devices WHERE user_id=?",alert,owner);
        mvc.perform(delete("/api/v1/me/account").header("Authorization",token).contentType("application/json")
                .content("{\"currentPassword\":\"abcdefgh\",\"userId\":\""+otherId+"\"}")).andExpect(status().isNoContent());
        for(String table:List.of("auth_sessions","user_preferences","comparisons","product_watches","price_alerts","push_devices"))
            assertThat(count(table,owner)).as(table).isZero();
        assertThat(jdbc.queryForObject("SELECT count(*) FROM alert_deliveries WHERE alert_id=?",Integer.class,alert)).isZero();
        for(var s:List.of(first,second)) {
            mvc.perform(get("/api/v1/auth/me").header("Authorization",auth(s))).andExpect(status().isUnauthorized());
            mvc.perform(post("/api/v1/auth/refresh").contentType("application/json").content("{\"refreshToken\":\""+s.path("refreshToken").asText()+"\"}"))
                    .andExpect(status().isUnauthorized());
        }
        mvc.perform(post("/api/v1/auth/login").contentType("application/json").content("{\"email\":\""+email+"\",\"password\":\"abcdefgh\"}"))
                .andExpect(status().isUnauthorized());
        assertThat(count("product_watches",otherId)).isEqualTo(1);
        mvc.perform(get("/api/v1/auth/me").header("Authorization",other)).andExpect(status().isOk());
        mvc.perform(get("/api/v1/products/"+PRODUCT)).andExpect(status().isOk());
        String newToken=auth(session(email,true));
        assertThat(accounts.authenticate(newToken).toString()).isNotEqualTo(owner);
        assertThat(watches.list(newToken)).isEmpty();
    }

    @Test void administratorDeletionPreservesSharedCatalogAndAnonymizesAudit() throws Exception {
        String token=auth(session(email(),true)),owner=accounts.authenticate(token).toString();
        jdbc.update("UPDATE app_users SET is_admin=TRUE WHERE id=?",owner);
        jdbc.update("INSERT INTO product_changes(product_id,actor_id,action,after_json) VALUES (?,?,'UPDATE','{\"name\":\"Audit preserved\"}')",PRODUCT,owner);
        Long audit=jdbc.queryForObject("SELECT id FROM product_changes WHERE actor_id=?",Long.class,owner);
        mvc.perform(delete("/api/v1/me/account").header("Authorization",token).contentType("application/json").content("{\"currentPassword\":\"abcdefgh\"}"))
                .andExpect(status().isNoContent());
        assertThat(jdbc.queryForObject("SELECT actor_id FROM product_changes WHERE id=?",String.class,audit)).isNull();
        assertThat(jdbc.queryForObject("SELECT after_json FROM product_changes WHERE id=?",String.class,audit)).contains("Audit preserved");
        mvc.perform(get("/api/v1/products/"+PRODUCT)).andExpect(status().isOk());
    }
}
