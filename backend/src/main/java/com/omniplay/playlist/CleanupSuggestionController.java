package com.omniplay.playlist;

import com.omniplay.catalog.CatalogInputValidator;
import com.omniplay.dto.request.CleanupSuggestionActionRequest;
import com.omniplay.dto.response.CleanupSuggestionActionResponse;
import com.omniplay.dto.response.CleanupSuggestionListResponse;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/me/cleanup-suggestions")
public class CleanupSuggestionController {
    private final CleanupSuggestionService service;
    private final CatalogInputValidator input;

    public CleanupSuggestionController(CleanupSuggestionService service, CatalogInputValidator input) {
        this.service = service;
        this.input = input;
    }

    @GetMapping
    public CleanupSuggestionListResponse list(@AuthenticationPrincipal Jwt jwt) {
        return service.list(UUID.fromString(jwt.getSubject()));
    }

    @PatchMapping("/{playlistItemId}")
    public CleanupSuggestionActionResponse applyAction(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable String playlistItemId,
            @RequestBody CleanupSuggestionActionRequest request) {
        return service.applyAction(
                UUID.fromString(jwt.getSubject()),
                input.uuid(playlistItemId, "playlistItemId"),
                request);
    }
}
