package com.pickwise.api;
import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.*;
import com.google.firebase.messaging.*;
import org.springframework.stereotype.Component;
import org.springframework.beans.factory.annotation.Value;
@Component
public class FcmGateway {
 private FirebaseMessaging messaging;
 public FcmGateway(@Value("${pickwise.firebase.enabled:false}") boolean enabled) {
  if(enabled) {
   try {messaging=FirebaseMessaging.getInstance(FirebaseApp.initializeApp(FirebaseOptions.builder().setCredentials(GoogleCredentials.getApplicationDefault()).build(),"pickwise-push"));}
   catch(Exception e){org.slf4j.LoggerFactory.getLogger(FcmGateway.class).warn("Firebase push credentials are unavailable; inbox remains enabled");}
  }
 }
 public boolean available(){return messaging!=null;}
 public void send(String token,String alertId) throws FirebaseMessagingException {
  if(messaging==null)throw new IllegalStateException("Firebase not configured");
  messaging.send(Message.builder().setFid(token)
   .setNotification(Notification.builder().setTitle("PickWise 가격 알림").setBody("새로운 가격 알림이 있어요. 로그인한 계정의 알림함에서 확인해주세요.").build())
   .putData("alertId",alertId)
   .setAndroidConfig(AndroidConfig.builder().setTtl(300000).setCollapseKey(alertId).build())
   .setApnsConfig(ApnsConfig.builder().putHeader("apns-collapse-id",alertId).setAps(Aps.builder().setSound("default").build()).build()).build());
 }
}
