package com.pickwise.api;
import java.util.Map;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
@RestController
@RequestMapping("/api/v1/me/preferences")
public class PreferenceController {
    private final JdbcTemplate jdbc;
    private final AccountService accounts;
    private final ObjectMapper mapper;
    public PreferenceController(JdbcTemplate jdbc,AccountService accounts,ObjectMapper mapper) {
        this.jdbc=jdbc;this.accounts=accounts;this.mapper=mapper;
    }
    @GetMapping
    public Map<String,JsonNode> get(@RequestHeader(value="Authorization",required=false) String header) {
        var owner=accounts.authenticate(header).toString();
        var rows=jdbc.queryForList("SELECT preferences FROM user_preferences WHERE user_id=?",String.class,owner);
        return Map.of("preferences",rows.isEmpty()?mapper.createObjectNode():mapper.readTree(rows.getFirst()));
    }
    @PutMapping
    public Map<String,JsonNode> save(@RequestHeader(value="Authorization",required=false) String header,@RequestBody JsonNode body) {
        var owner=accounts.authenticate(header).toString();
        PreferenceValidator.validate(body);
        jdbc.update("INSERT INTO user_preferences(user_id,preferences) VALUES (?,?) ON DUPLICATE KEY UPDATE preferences=VALUES(preferences)",owner,body.toString());
        return Map.of("preferences",body);
    }
}
