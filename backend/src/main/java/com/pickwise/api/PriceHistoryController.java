package com.pickwise.api;

import jakarta.validation.constraints.Pattern;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/v1/products")
public class PriceHistoryController {
    private final ProductCatalogRepository products;
    private final PriceHistoryRepository history;

    public PriceHistoryController(ProductCatalogRepository products, PriceHistoryRepository history) {
        this.products=products; this.history=history;
    }

    @GetMapping("/{id}/price-history")
    public PriceHistoryResponse list(@PathVariable String id,
            @RequestParam(defaultValue="30") int days,
            @RequestParam(defaultValue="automatic") String kind,
            @RequestParam(required=false) @Pattern(regexp="[a-f0-9]{64}") String source) {
        if ((days!=7 && days!=30 && days!=90) || (!kind.equals("automatic") && !kind.equals("manual"))) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"기간 또는 확인 방식을 확인해주세요.");
        }
        var product=products.findById(id).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND));
        return history.find(product,days,kind,source);
    }
}
