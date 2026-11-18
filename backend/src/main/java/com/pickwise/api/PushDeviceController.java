package com.pickwise.api;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.Map;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.HttpStatus;
@RestController @RequestMapping("/api/v1/me")
public class PushDeviceController {
 private final PushDeliveryService delivery;
 public PushDeviceController(PushDeliveryService delivery){this.delivery=delivery;}
 public record Device(@NotBlank @Size(max=4096) String token,@NotNull @Pattern(regexp="android|ios") String platform){}
 @GetMapping("/push-status") public Map<String,Boolean> status(@RequestHeader(value="Authorization",required=false) String h){return Map.of("configured",delivery.configured(h));}
 @PutMapping("/push-device") @ResponseStatus(HttpStatus.NO_CONTENT) public void register(@RequestHeader(value="Authorization",required=false) String h,@Valid @RequestBody Device d){delivery.register(h,d.token(),d.platform());}
 @DeleteMapping("/push-device") @ResponseStatus(HttpStatus.NO_CONTENT) public void unregister(@RequestHeader(value="Authorization",required=false) String h,@Valid @RequestBody Device d){delivery.unregister(h,d.token());}
}
