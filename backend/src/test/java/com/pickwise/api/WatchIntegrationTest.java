package com.pickwise.api;
import static org.assertj.core.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import java.time.Instant;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.ObjectMapper;

@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test") @Transactional
class WatchIntegrationTest {
 @Autowired MockMvc mvc;@Autowired JdbcTemplate jdbc;@Autowired ObjectMapper mapper;
 @Autowired WatchService watches;@Autowired PriceHistoryRepository history;@Autowired ProductCatalogRepository products;@Autowired AccountService accounts;
 static final String ID="sony-wf-1000xm5",URL="https://prod.danawa.com/info/?pcode=27250154";
 String account() throws Exception {
  var result=mvc.perform(post("/api/v1/auth/register").contentType("application/json").content("{\"email\":\""+UUID.randomUUID()+"@example.test\",\"password\":\"abcdefgh\"}"))
   .andExpect(status().isCreated()).andReturn();return "Bearer "+mapper.readTree(result.getResponse().getContentAsString()).path("accessToken").asText();
 }
 void observe(int price){var p=products.findById(ID).orElseThrow();history.recordAutomatic(ID,URL,p.version(),price,Instant.now().plusMillis(5));}
 @Test void favoritesPersistAndAreOwnerIsolated() throws Exception {
  String a=account(),b=account();watches.save(a,ID,null,0);
  assertThat(watches.list(a)).hasSize(1);assertThat(watches.list(b)).isEmpty();
  mvc.perform(get("/api/v1/me/watches")).andExpect(status().isUnauthorized());
  mvc.perform(delete("/api/v1/me/watches/"+ID).header("Authorization",b)).andExpect(status().isNotFound());
  mvc.perform(put("/api/v1/me/watches/"+ID).header("Authorization",a).contentType("application/json").content("{\"targetPrice\":0,\"version\":0}")).andExpect(status().isBadRequest());
  watches.remove(a,ID);assertThat(watches.list(a)).isEmpty();
 }
 @Test void targetNotifiesOnceThenExplicitlyRearms() throws Exception {
  String a=account();watches.save(a,ID,150000,0);
  assertThat(watches.alerts(a)).isEmpty();observe(160000);assertThat(watches.alerts(a)).isEmpty();
  observe(150000);observe(140000);assertThat(watches.alerts(a)).hasSize(1);
  assertThat(watches.alerts(a).getFirst().get("price")).isEqualTo(150000);
  watches.save(a,ID,150000,0);observe(130000);assertThat(watches.alerts(a)).hasSize(2);
  mvc.perform(put("/api/v1/me/watches/"+ID).header("Authorization",a).contentType("application/json").content("{\"targetPrice\":1,\"version\":0}")).andExpect(status().isConflict());
 }
 @Test void wrongSourceManualInputAndOldObservationNeverTrigger() throws Exception {
  String a=account();watches.save(a,ID,999999,0);
  jdbc.update("UPDATE product_watches SET source_key=? WHERE user_id=?","a".repeat(64),accounts.authenticate(a).toString());observe(100000);assertThat(watches.alerts(a)).isEmpty();
  watches.save(a,ID,999999,0);
  var p=products.findById(ID).orElseThrow();history.recordAutomatic(ID,URL,p.version(),100000,Instant.now().minusSeconds(5));assertThat(watches.alerts(a)).isEmpty();
  p=products.findById(ID).orElseThrow();jdbc.update("UPDATE products SET version=version+1 WHERE id=?",ID);history.recordManual(products.findById(ID).orElseThrow());assertThat(watches.alerts(a)).isEmpty();
  observe(100000);assertThat(watches.alerts(a)).hasSize(1);
 }
 @Test void deletingWatchStopsNewAlertsAndOldAlertsRemainOwnerScoped() throws Exception {
  String a=account(),b=account();watches.save(a,ID,999999,0);observe(100000);
  UUID id=UUID.fromString(watches.alerts(a).getFirst().get("id").toString());
  mvc.perform(put("/api/v1/me/alerts/"+id+"/read").header("Authorization",b)).andExpect(status().isNotFound());
  watches.markRead(a,id);watches.markRead(a,id);assertThat(watches.alerts(a).getFirst().get("read")).isEqualTo(true);
  watches.remove(a,ID);observe(90000);assertThat(watches.alerts(a)).hasSize(1);assertThat(watches.alerts(b)).isEmpty();
 }
 @Test void alertFailureRollsBackPriceAndHistory() throws Exception {
  String a=account();watches.save(a,ID,999999,0);
  String watch=jdbc.queryForObject("SELECT id FROM product_watches WHERE user_id=?",String.class,accounts.authenticate(a).toString());
  jdbc.update("INSERT INTO price_alerts(id,user_id,watch_id,rule_version,product_id,product_name,price,target_price,source_url,observed_at) VALUES (?,?,?,0,?,'Test',1,999999,?,now())",UUID.randomUUID().toString(),accounts.authenticate(a).toString(),watch,ID,URL);
  var before=products.findById(ID).orElseThrow();
  assertThatThrownBy(()->history.recordAutomatic(ID,URL,before.version(),123,Instant.now())).isInstanceOf(org.springframework.dao.DataIntegrityViolationException.class);
 }
 @Test void pushDeviceBindingAndDeliveryAreOwnerScopedAndDeduplicated() throws Exception {
  String a=account(),b=account();
  class Gateway extends FcmGateway {int sent;Gateway(){super(false);}public boolean available(){return true;}public void send(String token,String alert){sent++;}}
  var gateway=new Gateway();var delivery=new PushDeliveryService(jdbc,accounts,gateway);
  delivery.register(a,"fake-test-token","android");watches.save(a,ID,999999,0);observe(100000);
  delivery.deliver();delivery.deliver();assertThat(gateway.sent).isEqualTo(1);
  delivery.register(b,"fake-test-token","android");
  watches.save(a,ID,999999,0);observe(90000);delivery.deliver();assertThat(gateway.sent).isEqualTo(1);
  mvc.perform(get("/api/v1/me/push-status")).andExpect(status().isUnauthorized());
  mvc.perform(put("/api/v1/me/push-device").header("Authorization",a).contentType("application/json").content("{\"token\":\"\",\"platform\":\"bad\"}")).andExpect(status().isBadRequest());
 }
 @Test @Transactional(propagation=org.springframework.transaction.annotation.Propagation.NOT_SUPPORTED)
 void notificationFailureRollsBackObservedPriceAndHistory() throws Exception {
  String a=account(),owner=accounts.authenticate(a).toString(),id="atomic-alert-"+UUID.randomUUID();
  try {
   jdbc.update("INSERT INTO products(id,brand,name,category,price,price_checked_at,price_comparison_site,price_comparison_url) VALUES (?,'Test','Atomic alert','earbuds',1000000,'2026-11-01','danawa',?)",id,URL);
   watches.save(a,id,999999,0);
   String watch=jdbc.queryForObject("SELECT id FROM product_watches WHERE user_id=?",String.class,owner);
   jdbc.update("INSERT INTO price_alerts(id,user_id,watch_id,rule_version,product_id,product_name,price,target_price,source_url,observed_at) VALUES (?,?,?,0,?,'Test',1,999999,?,now())",UUID.randomUUID().toString(),owner,watch,id,URL);
   assertThatThrownBy(()->history.recordAutomatic(id,URL,0,100000,Instant.now())).isInstanceOf(org.springframework.dao.DataIntegrityViolationException.class);
   assertThat(products.findById(id).orElseThrow().price()).isEqualTo(1000000);
   assertThat(products.findById(id).orElseThrow().version()).isZero();
   assertThat(jdbc.queryForObject("SELECT count(*) FROM product_price_history WHERE product_id=?",Integer.class,id)).isZero();
   assertThat(jdbc.queryForObject("SELECT armed FROM product_watches WHERE id=?",Boolean.class,watch)).isTrue();
  }finally{jdbc.update("DELETE FROM app_users WHERE id=?",owner);jdbc.update("DELETE FROM products WHERE id=?",id);}
 }

}
