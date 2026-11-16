package com.pickwise.api;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class ProductApiIntegrationTest {
    @Autowired MockMvc mvc;
    @Autowired JdbcTemplate jdbc;
    @Autowired ProductCatalogRepository repository;
    @Autowired CatalogSeedLoader seedLoader;

    @Test
    void listsSeededProductsAndSupportsSearchAndPaging() throws Exception {
        mvc.perform(get("/api/v1/products"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.total").value(20))
                .andExpect(jsonPath("$.items.length()").value(20));

        mvc.perform(get("/api/v1/products")
                        .param("category", "earbuds")
                        .param("query", "Sony")
                        .param("sort", "priceAsc")
                        .param("size", "2"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.total").isNumber())
                .andExpect(jsonPath("$.items[0].brand").value("Sony"));

        mvc.perform(get("/api/v1/products").param("page", "1").param("size", "3"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(3))
                .andExpect(jsonPath("$.page").value(1));
    }

    @Test
    void returnsProductSpecificationsWithOriginalValueTypes() throws Exception {
        mvc.perform(get("/api/v1/products/sony-wf-1000xm5"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("WF-1000XM5"))
                .andExpect(jsonPath("$.price").value(234710))
                .andExpect(jsonPath("$.specs[?(@.key=='anc')].value").value(true));
    }

    @Test
    void handlesMissingProductsAndInvalidParameters() throws Exception {
        mvc.perform(get("/api/v1/products/not-a-product"))
                .andExpect(status().isNotFound());
        mvc.perform(get("/api/v1/products").param("sort", "unknown"))
                .andExpect(status().isBadRequest());
        mvc.perform(get("/api/v1/products").param("size", "51"))
                .andExpect(status().isBadRequest());
    }

    @Test
    @Transactional
    void seedingDoesNotOverwriteDatabaseChanges() throws Exception {
        jdbc.update("UPDATE products SET price = 123456 WHERE id = ?", "sony-wf-1000xm5");
        seedLoader.run(null);
        assertThat(repository.findById("sony-wf-1000xm5").orElseThrow().price())
                .isEqualTo(123456);
    }
}
