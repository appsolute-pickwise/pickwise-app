package com.pickwise.api;

import static org.assertj.core.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import tools.jackson.databind.ObjectMapper;

@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test")
class AccountComparisonTest {
    @Autowired MockMvc mvc;
    @Autowired JdbcTemplate jdbc;
    @Autowired ObjectMapper mapper;
    String credentials(String email) {
        return "{\"email\":\""+email+"\",\"password\":\"integration-test-password\"}";
    }
    String register() throws Exception {
        String email=UUID.randomUUID()+"@example.test";
        var response=mvc.perform(post("/api/v1/auth/register").contentType("application/json")
                .content(credentials(email))).andExpect(status().isCreated()).andReturn();
        return mapper.readTree(response.getResponse().getContentAsString()).path("token").asText();
    }
    String body(int version) {
        return "{\"title\":\"비교\",\"productIds\":[\"sony-wf-1000xm5\"],\"preferences\":{\"weights\":{\"ANC\":3}},\"version\":"+version+"}";
    }
    @Test void ownerIsolationConflictAndLogout() throws Exception {
        String a=register(),b=register();
        var result=mvc.perform(post("/api/v1/me/comparisons").header("Authorization","Bearer "+a)
                .contentType("application/json").content(body(0))).andExpect(status().isCreated()).andReturn();
        String id=mapper.readTree(result.getResponse().getContentAsString()).path("id").asText();
        String url="/api/v1/me/comparisons/"+id;
        mvc.perform(get("/api/v1/me/comparisons").header("Authorization","Bearer "+b))
                .andExpect(status().isOk()).andExpect(content().json("[]"));
        mvc.perform(put(url).header("Authorization","Bearer "+b).contentType("application/json").content(body(0)))
                .andExpect(status().isNotFound());
        mvc.perform(delete(url).header("Authorization","Bearer "+b)).andExpect(status().isNotFound());
        mvc.perform(put(url).header("Authorization","Bearer "+a).contentType("application/json").content(body(0)))
                .andExpect(status().isOk()).andExpect(jsonPath("$.version").value(1));
        mvc.perform(put(url).header("Authorization","Bearer "+a).contentType("application/json").content(body(0)))
                .andExpect(status().isConflict());
        mvc.perform(post("/api/v1/auth/logout").header("Authorization","Bearer "+a)).andExpect(status().isNoContent());
        mvc.perform(get("/api/v1/me/comparisons").header("Authorization","Bearer "+a)).andExpect(status().isUnauthorized());
        assertThat(jdbc.queryForObject("SELECT count(*) FROM auth_sessions WHERE token_hash=?",Integer.class,a)).isZero();
    }
    @Test void rejectsInvalidProductsAndExpiredSessions() throws Exception {
        String token=register();
        for(String invalid:new String[]{body(0).replace("[\"sony-wf-1000xm5\"]","[]"),
                body(0).replace("[\"sony-wf-1000xm5\"]","[\"sony-wf-1000xm5\",\"sony-wf-1000xm5\"]"),
                body(0).replace("sony-wf-1000xm5","missing-product"),body(0).replace("\"ANC\":3","\"ANC\":9")}) {
            mvc.perform(post("/api/v1/me/comparisons").header("Authorization","Bearer "+token)
                    .contentType("application/json").content(invalid)).andExpect(status().isBadRequest());
        }
        String hash=java.util.HexFormat.of().formatHex(java.security.MessageDigest.getInstance("SHA-256").digest(token.getBytes(java.nio.charset.StandardCharsets.UTF_8)));
        jdbc.update("UPDATE auth_sessions SET expires_at=DATE_SUB(now(), INTERVAL 1 SECOND) WHERE token_hash=?",hash);
        mvc.perform(get("/api/v1/me/comparisons").header("Authorization","Bearer "+token)).andExpect(status().isUnauthorized());
    }
    @Test void loginAndPasswordHash() throws Exception {
        String email=UUID.randomUUID()+"@example.test";
        mvc.perform(post("/api/v1/auth/register").contentType("application/json").content(credentials(email)))
                .andExpect(status().isCreated());
        String stored=jdbc.queryForObject("SELECT password_hash FROM app_users WHERE email=?",String.class,email);
        assertThat(stored).doesNotContain("integration-test-password");
        mvc.perform(post("/api/v1/auth/login").contentType("application/json").content(credentials(email)))
                .andExpect(status().isOk()).andExpect(jsonPath("$.token").isString());
        mvc.perform(post("/api/v1/auth/login").contentType("application/json")
                .content(credentials(email).replace("integration-test-password","incorrect-password")))
                .andExpect(status().isUnauthorized());
    }

    @Test void acceptsEightCharactersAndRejectsSeven() throws Exception {
        String email=UUID.randomUUID()+"@example.test";
        String eight=credentials(email).replace("integration-test-password","abcdefgh");
        String seven=credentials(email).replace("integration-test-password","abcdefg");
        mvc.perform(post("/api/v1/auth/register").contentType("application/json").content(seven))
                .andExpect(status().isBadRequest());
        mvc.perform(post("/api/v1/auth/register").contentType("application/json").content(eight))
                .andExpect(status().isCreated());
        mvc.perform(post("/api/v1/auth/login").contentType("application/json").content(eight))
                .andExpect(status().isOk());
    }
}
