package com.pickwise.api;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

@RestController
@RequestMapping("/api/v1/me/comparisons")
public class ComparisonController {
    private final JdbcTemplate jdbc;
    private final AccountService accounts;
    private final ProductCatalogRepository products;
    private final ObjectMapper mapper;
    public ComparisonController(JdbcTemplate jdbc, AccountService accounts,
                                ProductCatalogRepository products, ObjectMapper mapper) {
        this.jdbc=jdbc; this.accounts=accounts; this.products=products; this.mapper=mapper;
    }
    public record Input(@NotBlank @Size(max=100) String title,
                        @NotNull @Size(min=1,max=3) List<@NotBlank String> productIds,
                        @NotNull JsonNode preferences, @Min(0) int version) {}

    @GetMapping
    public List<Map<String,Object>> list(@RequestHeader(value="Authorization",required=false) String header) {
        UUID owner=accounts.authenticate(header);
        return jdbc.query("SELECT * FROM comparisons WHERE user_id=? ORDER BY updated_at DESC,id LIMIT 100",
                (rs,n)->Map.<String,Object>of("id",rs.getString("id"),"title",rs.getString("title"),
                        "productIds",mapper.readTree(rs.getString("product_ids")),
                        "preferences",mapper.readTree(rs.getString("preferences")),
                        "version",rs.getInt("version"), "snapshot",rs.getString("snapshot")==null?mapper.nullNode():mapper.readTree(rs.getString("snapshot"))), owner.toString());
    }
    @PostMapping @ResponseStatus(HttpStatus.CREATED) @Transactional
    public Map<String,Object> create(@RequestHeader(value="Authorization",required=false) String header,
                                     @Valid @RequestBody Input body) {
        UUID owner=accounts.authenticate(header); validate(body);
        UUID id=UUID.randomUUID();
        jdbc.update("INSERT INTO comparisons(id,user_id,title,product_ids,preferences,snapshot) VALUES (?,?,?,?,?,?)",
                id.toString(),owner.toString(),body.title(),mapper.writeValueAsString(body.productIds()),body.preferences().toString(),snapshot(body));
        return Map.of("id",id,"version",0);
    }
    @PutMapping("/{id}") @Transactional
    public Map<String,Object> update(@RequestHeader(value="Authorization",required=false) String header,
                                     @PathVariable UUID id,@Valid @RequestBody Input body) {
        UUID owner=accounts.authenticate(header); own(id,owner); validate(body);
        int changed=jdbc.update("UPDATE comparisons SET title=?,product_ids=?,preferences=?,snapshot=?,version=version+1,updated_at=now() WHERE id=? AND user_id=? AND version=?",
                body.title(),mapper.writeValueAsString(body.productIds()),body.preferences().toString(),snapshot(body),id.toString(),owner.toString(),body.version());
        if(changed==0) throw new ResponseStatusException(HttpStatus.CONFLICT,"다른 곳에서 수정된 기록입니다. 새로고침해주세요.");
        return Map.of("id",id,"version",body.version()+1);
    }
    @DeleteMapping("/{id}") @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@RequestHeader(value="Authorization",required=false) String header,@PathVariable UUID id) {
        UUID owner=accounts.authenticate(header);
        if(jdbc.update("DELETE FROM comparisons WHERE id=? AND user_id=?",id.toString(),owner.toString())==0)
            throw new ResponseStatusException(HttpStatus.NOT_FOUND,"기록을 찾을 수 없습니다.");
    }
    private String snapshot(Input body) {
        return mapper.writeValueAsString(Map.of("products", body.productIds().stream().map(id->products.findById(id).orElseThrow()).toList(),
                "preferences",body.preferences(),"ruleVersion","2026-11-fair-v1","savedAt",java.time.Instant.now().toString()));
    }
    private void own(UUID id,UUID owner) {
        if(jdbc.queryForObject("SELECT count(*) FROM comparisons WHERE id=? AND user_id=?",Integer.class,id.toString(),owner.toString())==0)
            throw new ResponseStatusException(HttpStatus.NOT_FOUND,"기록을 찾을 수 없습니다.");
    }
    private void validate(Input body) {
        if(new HashSet<>(body.productIds()).size()!=body.productIds().size()) bad();
        String category=null;
        for(String id:body.productIds()) {
            ProductResponse product=products.findById(id).orElseThrow(()->new ResponseStatusException(HttpStatus.BAD_REQUEST,"없는 제품입니다."));
            if(category!=null&&!category.equals(product.category())) bad();
            category=product.category();
        }
        PreferenceValidator.validate(body.preferences());
    }
    private void bad() { throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"비교 입력을 확인해주세요."); }
}
