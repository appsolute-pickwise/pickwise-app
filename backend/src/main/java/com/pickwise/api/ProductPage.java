package com.pickwise.api;

import java.util.List;

public record ProductPage(List<ProductResponse> items, int page, int size, long total) {}
