package com.pickwise.api;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/v1/products")
public class ProductController {
    private final ProductCatalogRepository repository;

    public ProductController(ProductCatalogRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    public ProductPage list(
            @RequestParam(required = false) @Size(max = 80) String category,
            @RequestParam(required = false) @Size(max = 120) String query,
            @RequestParam(defaultValue = "name") String sort,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(50) int size) {
        if (!sort.equals("name") && !sort.equals("priceAsc") && !sort.equals("priceDesc")) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unsupported sort value");
        }
        return repository.findPage(category, query, sort, page, size);
    }

    @GetMapping("/{id}")
    public ProductResponse detail(@PathVariable String id) {
        return repository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Product not found"));
    }
}
