package com.pickwise.api;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.UUID;
import java.util.Map;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.sql.Timestamp;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class AccountService {
    private final JdbcTemplate jdbc;
    private final SecureRandom random = new SecureRandom();
    public AccountService(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    @Transactional
    public Map<String,String> register(String email, String password) {
        byte[] salt = new byte[16]; random.nextBytes(salt);
        String hash = Base64.getEncoder().encodeToString(salt) + ":" + derive(password, salt);
        try {
            jdbc.update("INSERT INTO app_users(id,email,password_hash) VALUES (?,?,?)",
                    UUID.randomUUID().toString(), email.toLowerCase(java.util.Locale.ROOT), hash);
        } catch (DuplicateKeyException e) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "이미 등록된 이메일입니다.");
        }
        return login(email, password);
    }

    @Transactional
    public Map<String,String> login(String email, String password) {
        var rows = jdbc.queryForList("SELECT id,password_hash FROM app_users WHERE email=? FOR UPDATE",
                email.toLowerCase(java.util.Locale.ROOT));
        // Unknown accounts still perform the expensive hash operation.
        String hash = rows.isEmpty() ? Base64.getEncoder().encodeToString(new byte[16]) + ":invalid"
                : (String) rows.getFirst().get("password_hash");
        String[] parts = hash.split(":", 2);
        String actual = derive(password, Base64.getDecoder().decode(parts[0]));
        if (rows.isEmpty() || !MessageDigest.isEqual(actual.getBytes(StandardCharsets.UTF_8),
                parts[1].getBytes(StandardCharsets.UTF_8))) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "이메일 또는 비밀번호를 확인해주세요.");
        }
        return issue(rows.getFirst().get("id").toString(), Instant.now().plus(30, ChronoUnit.DAYS));
    }

    private String randomToken() {
        byte[] bytes = new byte[32]; random.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }
    private Map<String,String> issue(String owner, Instant refreshExpiry) {
        String access=randomToken(), refresh=randomToken();
        // MySQL TIMESTAMP(6)과 응답의 만료 시각 정밀도를 일치시킨다.
        Instant expiry=Instant.now().plus(15, ChronoUnit.MINUTES).truncatedTo(ChronoUnit.MICROS);
        Instant refreshDeadline=refreshExpiry.truncatedTo(ChronoUnit.MICROS);
        jdbc.update("INSERT INTO auth_sessions(token_hash,user_id,expires_at,refresh_hash,refresh_expires_at) VALUES (?,?,?,?,?)",
                digest(access),owner,Timestamp.from(expiry),digest(refresh),Timestamp.from(refreshDeadline));
        return Map.of("token",access,"accessToken",access,"refreshToken",refresh,
                "expiresAt",expiry.toString(),"refreshExpiresAt",refreshDeadline.toString());
    }
    @Transactional
    public Map<String,String> refresh(String token) {
        if(token==null || token.length()>150) throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
        var owners=jdbc.queryForList("SELECT user_id FROM auth_sessions WHERE refresh_hash=?",String.class,digest(token));
        if(owners.isEmpty()) throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
        jdbc.queryForList("SELECT id FROM app_users WHERE id=? FOR UPDATE",owners.getFirst());
        var rows=jdbc.queryForList("SELECT user_id,refresh_expires_at FROM auth_sessions WHERE refresh_hash=? AND refresh_expires_at>now() FOR UPDATE",digest(token));
        if(rows.isEmpty()) throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
        var row=rows.getFirst();
        jdbc.update("DELETE FROM auth_sessions WHERE refresh_hash=?",digest(token));
        return issue(row.get("user_id").toString(),((Timestamp)row.get("refresh_expires_at")).toInstant());
    }
    public Map<String,String> me(String header) {
        UUID owner=authenticate(header);
        return Map.of("id",owner.toString(),"email",jdbc.queryForObject("SELECT email FROM app_users WHERE id=?",String.class,owner.toString()));
    }

    public UUID authenticate(String header) {
        if (header == null || !header.startsWith("Bearer ") || header.length() > 150) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "로그인이 필요합니다.");
        }
        var ids = jdbc.query("SELECT user_id FROM auth_sessions WHERE token_hash=? AND expires_at>now()",
                (rs, n) -> UUID.fromString(rs.getString(1)), digest(header.substring(7)));
        if (ids.isEmpty()) throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "로그인이 만료됐습니다.");
        return ids.getFirst();
    }

    public void logout(String header) {
        authenticate(header);
        jdbc.update("DELETE FROM auth_sessions WHERE token_hash=?", digest(header.substring(7)));
    }

    @Transactional
    public void changePassword(String header,String currentPassword,String newPassword) {
        UUID owner=authenticate(header);
        String hash=jdbc.queryForObject("SELECT password_hash FROM app_users WHERE id=? FOR UPDATE",String.class,owner.toString());
        authenticate(header);
        String[] parts=hash.split(":",2);
        String actual=derive(currentPassword,Base64.getDecoder().decode(parts[0]));
        if(!MessageDigest.isEqual(actual.getBytes(StandardCharsets.UTF_8),parts[1].getBytes(StandardCharsets.UTF_8)))
            throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY,"현재 비밀번호를 확인해주세요.");
        byte[] salt=new byte[16];random.nextBytes(salt);
        jdbc.update("UPDATE app_users SET password_hash=? WHERE id=?",Base64.getEncoder().encodeToString(salt)+":"+derive(newPassword,salt),owner.toString());
        jdbc.update("DELETE FROM auth_sessions WHERE user_id=?",owner.toString());
    }

    private String derive(String password, byte[] salt) {
        PBEKeySpec key = new PBEKeySpec(password.toCharArray(), salt, 600000, 256);
        try {
            return Base64.getEncoder().encodeToString(SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
                    .generateSecret(key).getEncoded());
        } catch (Exception e) { throw new IllegalStateException("Password hashing unavailable", e); }
        finally { key.clearPassword(); }
    }
    private String digest(String token) {
        try { return java.util.HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                .digest(token.getBytes(StandardCharsets.UTF_8))); }
        catch (Exception e) { throw new IllegalStateException(e); }
    }
}
