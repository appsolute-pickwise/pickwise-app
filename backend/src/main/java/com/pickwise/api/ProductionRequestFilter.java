package com.pickwise.api;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.Clock;
import java.util.HashMap;
import java.util.Map;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
@Component @Profile("production")
public class ProductionRequestFilter extends OncePerRequestFilter {
    private record Window(long start,int count) {}
    private final Map<String,Window> windows=new HashMap<>();
    @org.springframework.beans.factory.annotation.Value("${pickwise.trust-proxy:false}")
    private boolean trustProxy;
    private final Clock clock;
    public ProductionRequestFilter() {this(Clock.systemUTC());}
    ProductionRequestFilter(Clock clock) {this.clock=clock;}
    private synchronized boolean allow(String key,int limit) {
        long now=clock.millis();
        windows.entrySet().removeIf(e->now-e.getValue().start()>=60000);
        var w=windows.get(key);
        if(w==null) {
            if(windows.size()>=10000) return false;
            windows.put(key,new Window(now,1));return true;
        }
        if(w.count()>=limit) return false;
        windows.put(key,new Window(w.start(),w.count()+1));return true;
    }
    @Override protected void doFilterInternal(HttpServletRequest req,HttpServletResponse res,FilterChain chain) throws ServletException,IOException {
        res.setHeader("X-Content-Type-Options","nosniff");
        res.setHeader("X-Frame-Options","DENY");
        res.setHeader("Referrer-Policy","no-referrer");
        String path;
        try {path=org.springframework.web.util.UriUtils.decode(req.getRequestURI(),java.nio.charset.StandardCharsets.UTF_8).split(";",2)[0];}
        catch(IllegalArgumentException error) {res.setStatus(400);return;}
        if(path.startsWith("/api/v1/me/")||path.startsWith("/api/v1/auth/")||path.startsWith("/api/v1/admin/")) res.setHeader("Cache-Control","no-store");
        boolean credentials=path.equals("/api/v1/auth/login")||path.equals("/api/v1/auth/register");
        boolean refresh=path.equals("/api/v1/auth/refresh");
        if((credentials||refresh||path.equals("/api/v1/me/password")||path.equals("/api/v1/me/account")) && !req.getMethod().equals("GET")) {
            String kind=credentials?"credentials":refresh?"refresh":path.equals("/api/v1/me/account")?"account-deletion":"password";
            if(!allow((trustProxy && req.getHeader("X-Real-IP")!=null?req.getHeader("X-Real-IP"):req.getRemoteAddr())+":"+kind,refresh?60:credentials?20:5)) {
                res.setStatus(429);res.setHeader("Retry-After","60");res.setContentType("application/json;charset=UTF-8");
                res.getWriter().write("{\"message\":\"요청이 많아요. 잠시 후 다시 시도해주세요.\"}");return;
            }
        }
        chain.doFilter(req,res);
    }
}
