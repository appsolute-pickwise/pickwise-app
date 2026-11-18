package com.pickwise.api;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import java.util.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.HttpStatus;
@RestController @RequestMapping("/api/v1/me")
public class WatchController {
 private final WatchService watches;
 public WatchController(WatchService watches){this.watches=watches;}
 public record Input(@Min(1) Integer targetPrice,@Min(0) int version) {}
 @GetMapping("/watches") public List<Map<String,Object>> list(@RequestHeader(value="Authorization",required=false) String h){return watches.list(h);}
 @PutMapping("/watches/{id}") @ResponseStatus(HttpStatus.NO_CONTENT) public void save(@RequestHeader(value="Authorization",required=false) String h,@PathVariable String id,@Valid @RequestBody Input input){watches.save(h,id,input.targetPrice(),input.version());}
 @DeleteMapping("/watches/{id}") @ResponseStatus(HttpStatus.NO_CONTENT) public void remove(@RequestHeader(value="Authorization",required=false) String h,@PathVariable String id){watches.remove(h,id);}
 @GetMapping("/alerts") public List<Map<String,Object>> alerts(@RequestHeader(value="Authorization",required=false) String h){return watches.alerts(h);}
 @PutMapping("/alerts/{id}/read") @ResponseStatus(HttpStatus.NO_CONTENT) public void read(@RequestHeader(value="Authorization",required=false) String h,@PathVariable UUID id){watches.markRead(h,id);}
}
