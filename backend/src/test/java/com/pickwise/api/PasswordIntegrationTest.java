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
import tools.jackson.databind.ObjectMapper;
@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test")
class PasswordIntegrationTest {
 @Autowired MockMvc mvc;
 @Autowired ObjectMapper mapper;
 @Test void changeRevokesAllSessionsAndRequiresNewPassword() throws Exception {
  String email=UUID.randomUUID()+"@example.test";
  String credentials="{\"email\":\""+email+"\",\"password\":\"abcdefgh\"}";
  var first=mapper.readTree(mvc.perform(post("/api/v1/auth/register").contentType("application/json").content(credentials)).andExpect(status().isCreated()).andReturn().getResponse().getContentAsString());
  var second=mapper.readTree(mvc.perform(post("/api/v1/auth/login").contentType("application/json").content(credentials)).andReturn().getResponse().getContentAsString());
  String auth="Bearer "+first.path("accessToken").asText();
  mvc.perform(put("/api/v1/me/password").header("Authorization",auth).contentType("application/json").content("{\"currentPassword\":\"incorrect\",\"newPassword\":\"12345678\"}")).andExpect(status().isUnprocessableEntity());
  mvc.perform(get("/api/v1/auth/me").header("Authorization",auth)).andExpect(status().isOk());
  mvc.perform(put("/api/v1/me/password").header("Authorization",auth).contentType("application/json").content("{\"currentPassword\":\"abcdefgh\",\"newPassword\":\"12345678\"}")).andExpect(status().isNoContent());
  for(var s:java.util.List.of(first,second)) {
   mvc.perform(get("/api/v1/auth/me").header("Authorization","Bearer "+s.path("accessToken").asText())).andExpect(status().isUnauthorized());
   mvc.perform(post("/api/v1/auth/refresh").contentType("application/json").content("{\"refreshToken\":\""+s.path("refreshToken").asText()+"\"}")).andExpect(status().isUnauthorized());
  }
  mvc.perform(post("/api/v1/auth/login").contentType("application/json").content(credentials)).andExpect(status().isUnauthorized());
  mvc.perform(post("/api/v1/auth/login").contentType("application/json").content(credentials.replace("abcdefgh","12345678"))).andExpect(status().isOk());
 }
}
