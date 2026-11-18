package com.pickwise.api;
import static org.assertj.core.api.Assertions.*;
import java.time.*;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
class ProductionRequestFilterTest {
 @Test void deletionPasswordChecksAreLimitedAndNeverCached() throws Exception {
  var filter=new ProductionRequestFilter(new TestClock());
  for(int i=0;i<6;i++) {
   var response=new MockHttpServletResponse();
   filter.doFilter(new MockHttpServletRequest("DELETE","/api/v1/me/account"),response,(req,res)->{});
   assertThat(response.getStatus()).isEqualTo(i<5?200:429);
   assertThat(response.getHeader("Cache-Control")).isEqualTo("no-store");
  }
 }
 static class TestClock extends Clock {
  long millis;
  public ZoneId getZone(){return ZoneOffset.UTC;}
  public Clock withZone(ZoneId zone){return this;}
  public Instant instant(){return Instant.ofEpochMilli(millis);}
 }
 @Test void throttlesAndExpiresWindowWithoutTrustingClientHeaders() throws Exception {
  var clock=new TestClock();var filter=new ProductionRequestFilter(clock);
  for(int i=0;i<21;i++) {
   var req=new MockHttpServletRequest("POST","/api/v1/auth/login");req.setRemoteAddr("127.0.0.1");req.addHeader("X-Real-IP","spoof-"+i);
   var res=new MockHttpServletResponse();filter.doFilter(req,res,(request,response)->{});
   assertThat(res.getStatus()).isEqualTo(i<20?200:429);
   assertThat(res.getHeader("Cache-Control")).isEqualTo("no-store");
   if(i==20) assertThat(res.getHeader("Retry-After")).isEqualTo("60");
  }
  clock.millis=60000;
  var res=new MockHttpServletResponse();filter.doFilter(new MockHttpServletRequest("POST","/api/v1/auth/login"),res,(request,response)->{});
  assertThat(res.getStatus()).isEqualTo(200);
 }
}
