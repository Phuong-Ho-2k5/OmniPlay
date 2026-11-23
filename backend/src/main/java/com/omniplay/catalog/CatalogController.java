package com.omniplay.catalog;

import com.omniplay.dto.response.*;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/catalog")
public class CatalogController {
    private final CatalogService catalog;
    private final CatalogInputValidator input;
    public CatalogController(CatalogService catalog, CatalogInputValidator input) {
        this.catalog = catalog;
        this.input = input;
    }

    @GetMapping
    public PageResponse<ContentSummaryResponse> list(@AuthenticationPrincipal Jwt jwt,
            @RequestParam(required = false) String type, @RequestParam(required = false) String page,
            @RequestParam(required = false) String size) {
        return catalog.list(UUID.fromString(jwt.getSubject()), input.parse(null, type, null, page, size, false));
    }

    @GetMapping("/search")
    public PageResponse<ContentSummaryResponse> search(@AuthenticationPrincipal Jwt jwt,
            @RequestParam(required = false) String q, @RequestParam(required = false) String type,
            @RequestParam(required = false) String genreId, @RequestParam(required = false) String page,
            @RequestParam(required = false) String size) {
        return catalog.list(UUID.fromString(jwt.getSubject()), input.parse(q, type, genreId, page, size, false));
    }

    @GetMapping("/{id}")
    public ContentDetailResponse detail(@AuthenticationPrincipal Jwt jwt, @PathVariable String id,
            @RequestParam(required = false) String type) {
        var query = input.parse(null, type, null, null, null, true);
        return catalog.detail(UUID.fromString(jwt.getSubject()), input.uuid(id, "id"), query.type());
    }
}
