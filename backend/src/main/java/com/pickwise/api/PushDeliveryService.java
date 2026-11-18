package com.pickwise.api;
import java.util.*;
import org.springframework.stereotype.Service;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
@Service
public class PushDeliveryService {
 private final JdbcTemplate jdbc;private final AccountService accounts;private final FcmGateway gateway;
 public PushDeliveryService(JdbcTemplate jdbc,AccountService accounts,FcmGateway gateway){this.jdbc=jdbc;this.accounts=accounts;this.gateway=gateway;}
 public boolean available(){return gateway.available();}
 public boolean configured(String header){accounts.authenticate(header);return available();}
 @Transactional public void register(String header,String token,String platform){
  var owner=accounts.authenticate(header);
  jdbc.queryForList("SELECT id FROM app_users WHERE id=? FOR UPDATE",owner.toString());accounts.authenticate(header);
  String hash=PriceHistoryRepository.sourceKey("fcm",token);
  if(jdbc.queryForObject("SELECT count(*) FROM push_devices WHERE user_id=?",Integer.class,owner.toString())>=10 && jdbc.queryForObject("SELECT count(*) FROM push_devices WHERE token_hash=? AND user_id=?",Integer.class,hash,owner.toString())==0)throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
  jdbc.update("INSERT INTO push_devices(token_hash,user_id,device_token,platform) VALUES (?,?,?,?) ON DUPLICATE KEY UPDATE user_id=VALUES(user_id),device_token=VALUES(device_token),platform=VALUES(platform),updated_at=now()",hash,owner.toString(),token,platform);
 }
 public void unregister(String header,String token){var owner=accounts.authenticate(header);jdbc.update("DELETE FROM push_devices WHERE token_hash=? AND user_id=?",PriceHistoryRepository.sourceKey("fcm",token),owner.toString());}
 @Scheduled(initialDelay=45000,fixedDelay=30000) public void deliver(){
  if(!gateway.available())return;
  jdbc.update("INSERT IGNORE INTO alert_deliveries(alert_id,token_hash) SELECT a.id,d.token_hash FROM price_alerts a JOIN push_devices d ON d.user_id=a.user_id WHERE a.read_at IS NULL AND a.observed_at>=DATE_SUB(now(),INTERVAL 1 DAY) AND d.updated_at>=DATE_SUB(now(),INTERVAL 30 DAY)");
  var rows=jdbc.queryForList("SELECT q.alert_id,q.token_hash,d.device_token FROM alert_deliveries q JOIN price_alerts a ON a.id=q.alert_id JOIN push_devices d ON d.token_hash=q.token_hash AND d.user_id=a.user_id WHERE q.status<>'sent' AND q.attempts<3 AND a.read_at IS NULL AND a.observed_at>=DATE_SUB(now(),INTERVAL 1 DAY) AND (q.attempted_at IS NULL OR q.attempted_at<DATE_SUB(now(),INTERVAL 5 MINUTE)) ORDER BY a.observed_at LIMIT 100");
  for(var row:rows){
   int claimed=jdbc.update("UPDATE alert_deliveries SET status='processing',attempts=attempts+1,attempted_at=now() WHERE alert_id=? AND token_hash=? AND attempts<3 AND status<>'sent' AND (attempted_at IS NULL OR attempted_at<DATE_SUB(now(),INTERVAL 5 MINUTE))",row.get("alert_id"),row.get("token_hash"));
   if(claimed==0)continue;
   try{gateway.send(row.get("device_token").toString(),row.get("alert_id").toString());jdbc.update("UPDATE alert_deliveries SET status='sent' WHERE alert_id=? AND token_hash=?",row.get("alert_id"),row.get("token_hash"));}
   catch(Exception e){jdbc.update("UPDATE alert_deliveries SET status='failed' WHERE alert_id=? AND token_hash=?",row.get("alert_id"),row.get("token_hash"));}
  }
 }
}
