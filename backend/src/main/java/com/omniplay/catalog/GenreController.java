package com.omniplay.catalog;

import com.omniplay.dto.response.GenreListResponse;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class GenreController {
    private final CatalogService catalog;
    public GenreController(CatalogService catalog) { this.catalog = catalog; }
    @GetMapping("/genres")
    public GenreListResponse genres() { return catalog.genres(); }
}
