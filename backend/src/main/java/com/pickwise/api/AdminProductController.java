package com.pickwise.api;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import tools.jackson.databind.JsonNode;

@RestController
@RequestMapping("/api/v1/admin/products")
public class AdminProductController {
    private final CatalogManagementService catalog;

    public AdminProductController(CatalogManagementService catalog) { this.catalog = catalog; }

    public record Input(
            @NotBlank @Pattern(regexp="[a-z0-9]+(?:-[a-z0-9]+)*") @Size(max=120) String id,
            @NotBlank @Size(max=120) String brand,
            @NotBlank @Size(max=240) String name,
            @NotBlank @Pattern(regexp="earbuds") String category,
            @Size(max=400) String imageAsset,
            @NotNull @Size(max=8) List<@NotBlank @Size(max=100) String> tags,
            @NotNull @Min(1) Integer price,
            @NotNull LocalDate priceCheckedAt,
            @NotNull @Pattern(regexp="danawa|enuri|naver") String priceComparisonSite,
            @NotBlank @Size(max=1000) String priceComparisonUrl,
            @NotNull @Size(max=40) List<@NotNull @Valid Specification> specs,
            @NotNull @Min(0) Integer version,
            @NotNull Boolean priceAutoRefresh) {}

    public record Specification(
            @NotBlank @Pattern(regexp="[a-zA-Z][a-zA-Z0-9]*") @Size(max=100) String key,
            @NotBlank @Size(max=120) String label,
            @NotNull JsonNode value,
            @Size(max=40) String unit,
            @Size(max=1000) String sourceUrl,
            LocalDate checkedAt) {}

    @GetMapping("/{id}")
    public ProductResponse detail(@RequestHeader(value="Authorization",required=false) String header,
                                  @PathVariable String id) { return catalog.detail(header, id); }

    @PostMapping @ResponseStatus(HttpStatus.CREATED)
    public ProductResponse create(@RequestHeader(value="Authorization",required=false) String header,
                                   @Valid @RequestBody Input input) { return catalog.create(header, input); }

    @PutMapping("/{id}")
    public ProductResponse update(@RequestHeader(value="Authorization",required=false) String header,
                                   @PathVariable String id, @Valid @RequestBody Input input) {
        return catalog.update(header, id, input);
    }

    @GetMapping("/{id}/changes")
    public List<Map<String,Object>> changes(@RequestHeader(value="Authorization",required=false) String header,
                                            @PathVariable String id) { return catalog.changes(header, id); }
}
