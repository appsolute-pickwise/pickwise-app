package com.pickwise.api;
import static org.assertj.core.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test") @Transactional
class PersonalizationIntegrationTest {
    @Autowired MockMvc mvc;
    @Autowired JdbcTemplate jdbc;
    @Autowired ObjectMapper mapper;
    JsonNode account() throws Exception {
        var response=mvc.perform(post("/api/v1/auth/register").contentType("application/json")
                .content("{\"email\":\""+UUID.randomUUID()+"@example.test\",\"password\":\"abcdefgh\"}"))
                .andExpect(status().isCreated()).andReturn();
        return mapper.readTree(response.getResponse().getContentAsString());
    }
    String refresh(JsonNode session) {return "{\"refreshToken\":\""+session.path("refreshToken").asText()+"\"}";}
    void assertStoredExpiry(JsonNode session) {
        var stored=jdbc.queryForMap("SELECT expires_at,refresh_expires_at FROM auth_sessions WHERE token_hash=SHA2(?,256)",session.path("accessToken").asText());
        assertThat(Instant.parse(session.path("expiresAt").asText()))
                .isEqualTo(((Timestamp)stored.get("expires_at")).toInstant());
        assertThat(Instant.parse(session.path("refreshExpiresAt").asText()))
                .isEqualTo(((Timestamp)stored.get("refresh_expires_at")).toInstant());
    }
    @Test void rotatesRefreshOnceAndRevokesOnLogout() throws Exception {
        var old=account();
        assertStoredExpiry(old);
        var response=mvc.perform(post("/api/v1/auth/refresh").contentType("application/json").content(refresh(old)))
                .andExpect(status().isOk()).andReturn();
        var next=mapper.readTree(response.getResponse().getContentAsString());
        assertStoredExpiry(next);
        assertThat(next.path("refreshToken").asText()).isNotEqualTo(old.path("refreshToken").asText());
        assertThat(next.path("refreshExpiresAt").asText()).isEqualTo(old.path("refreshExpiresAt").asText());
        mvc.perform(post("/api/v1/auth/refresh").contentType("application/json").content(refresh(old))).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/auth/me").header("Authorization","Bearer "+old.path("accessToken").asText())).andExpect(status().isUnauthorized());
        String header="Bearer "+next.path("accessToken").asText();
        mvc.perform(get("/api/v1/auth/me").header("Authorization",header)).andExpect(status().isOk());
        mvc.perform(post("/api/v1/auth/logout").header("Authorization",header)).andExpect(status().isNoContent());
        mvc.perform(post("/api/v1/auth/refresh").contentType("application/json").content(refresh(next))).andExpect(status().isUnauthorized());
        assertThat(jdbc.queryForObject("SELECT count(*) FROM auth_sessions WHERE refresh_hash=?",Integer.class,next.path("refreshToken").asText())).isZero();
    }
    @Test void preferencesArePrivateAndValidated() throws Exception {
        var a=account();var b=account();
        String auth="Bearer "+a.path("accessToken").asText();
        String preference="{\"priorities\":[\"배터리\"],\"batteryCondition\":\"normal\",\"budget\":\"5만원 미만\"}";
        mvc.perform(put("/api/v1/me/preferences").header("Authorization",auth).contentType("application/json").content(preference)).andExpect(status().isOk());
        mvc.perform(get("/api/v1/me/preferences").header("Authorization",auth)).andExpect(jsonPath("$.preferences.batteryCondition").value("normal"));
        mvc.perform(get("/api/v1/me/preferences").header("Authorization","Bearer "+b.path("accessToken").asText()))
                .andExpect(content().json("{\"preferences\":{}}"));
        mvc.perform(put("/api/v1/me/preferences").header("Authorization",auth).contentType("application/json").content("{\"batteryCondition\":\"case\"}"))
                .andExpect(status().isBadRequest());
    }
    @Test void savedSnapshotSurvivesCatalogChangesAndLegacyRecordsStayUnknown() throws Exception {
        var a=account();String auth="Bearer "+a.path("accessToken").asText();
        String body="{\"title\":\"기록\",\"productIds\":[\"sony-wf-1000xm5\"],\"preferences\":{},\"version\":0}";
        mvc.perform(post("/api/v1/me/comparisons").header("Authorization",auth).contentType("application/json").content(body)).andExpect(status().isCreated());
        var before=mapper.readTree(mvc.perform(get("/api/v1/me/comparisons").header("Authorization",auth)).andReturn().getResponse().getContentAsString());
        var saved=before.get(0).path("snapshot");
        assertThat(saved.path("products").get(0).path("specs").size()).isPositive();
        jdbc.update("UPDATE products SET price=price+1000 WHERE id='sony-wf-1000xm5'");
        jdbc.update("UPDATE product_specifications SET value_json='99' WHERE product_id='sony-wf-1000xm5' AND `key`='batteryHoursAncOn'");
        var after=mapper.readTree(mvc.perform(get("/api/v1/me/comparisons").header("Authorization",auth)).andReturn().getResponse().getContentAsString());
        assertThat(after.get(0).path("snapshot")).isEqualTo(saved);
        jdbc.update("UPDATE comparisons SET snapshot=NULL WHERE id=?",before.get(0).path("id").asText());
        mvc.perform(get("/api/v1/me/comparisons").header("Authorization",auth)).andExpect(jsonPath("$[0].snapshot").isEmpty());
    }
}
