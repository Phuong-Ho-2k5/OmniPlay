package com.omniplay.playlist;

import com.omniplay.catalog.CatalogInputValidator;
import com.omniplay.dto.request.CreatePlaylistRequest;
import com.omniplay.dto.request.RenamePlaylistRequest;
import com.omniplay.dto.response.PageResponse;
import com.omniplay.dto.response.PlaylistDetailResponse;
import com.omniplay.dto.response.PlaylistItemAddedResponse;
import com.omniplay.dto.response.PlaylistRenamedResponse;
import com.omniplay.dto.response.PlaylistSummaryResponse;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/me/playlists")
public class PlaylistController {
    private final PlaylistService service;
    private final CatalogInputValidator input;

    public PlaylistController(PlaylistService service, CatalogInputValidator input) {
        this.service = service;
        this.input = input;
    }

    @GetMapping
    public PageResponse<PlaylistSummaryResponse> list(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(required = false) String page,
            @RequestParam(required = false) String size) {
        var query = input.parse(null, null, null, page, size, false);
        return service.list(UUID.fromString(jwt.getSubject()), query.page(), query.size());
    }

    @PostMapping
    public ResponseEntity<PlaylistSummaryResponse> create(
            @AuthenticationPrincipal Jwt jwt,
            @RequestBody CreatePlaylistRequest request) {
        var result = service.create(UUID.fromString(jwt.getSubject()), request);
        return ResponseEntity.status(result.created() ? HttpStatus.CREATED : HttpStatus.OK)
                .body(result.playlist());
    }

    @GetMapping("/{id}")
    public PlaylistDetailResponse detail(@AuthenticationPrincipal Jwt jwt, @PathVariable String id) {
        return service.detail(UUID.fromString(jwt.getSubject()), input.uuid(id, "id"));
    }

    @PatchMapping("/{id}")
    public PlaylistRenamedResponse rename(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable String id,
            @RequestBody RenamePlaylistRequest request) {
        return service.rename(UUID.fromString(jwt.getSubject()), input.uuid(id, "id"), request);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@AuthenticationPrincipal Jwt jwt, @PathVariable String id) {
        service.delete(UUID.fromString(jwt.getSubject()), input.uuid(id, "id"));
        return ResponseEntity.noContent().build();
    }

    @PutMapping("/{id}/items/{mediaId}")
    public PlaylistItemAddedResponse addItem(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable String id,
            @PathVariable String mediaId) {
        return service.addItem(
                UUID.fromString(jwt.getSubject()),
                input.uuid(id, "id"),
                input.uuid(mediaId, "mediaId"));
    }

    @DeleteMapping("/{id}/items/{mediaId}")
    public ResponseEntity<Void> removeItem(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable String id,
            @PathVariable String mediaId) {
        service.removeItem(
                UUID.fromString(jwt.getSubject()),
                input.uuid(id, "id"),
                input.uuid(mediaId, "mediaId"));
        return ResponseEntity.noContent().build();
    }
}
