package com.omniplay.playback;

import com.omniplay.catalog.CatalogInputValidator;
import com.omniplay.dto.request.CreatePlaybackAttemptRequest;
import com.omniplay.dto.request.PlaybackReportRequest;
import com.omniplay.dto.response.PlaybackAttemptResponse;
import com.omniplay.dto.response.PlaybackProgressResponse;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/me")
public class PlaybackProgressController {
    private final PlaybackProgressService service;
    private final CatalogInputValidator input;

    public PlaybackProgressController(PlaybackProgressService service, CatalogInputValidator input) {
        this.service = service;
        this.input = input;
    }

    @PostMapping("/playback-attempts")
    public ResponseEntity<PlaybackAttemptResponse> createAttempt(
            @AuthenticationPrincipal Jwt jwt,
            @RequestBody CreatePlaybackAttemptRequest request) {
        var result = service.createOrVerifyAttempt(UUID.fromString(jwt.getSubject()), request);
        return ResponseEntity.status(result.created() ? HttpStatus.CREATED : HttpStatus.OK)
                .body(result.response());
    }

    @PutMapping("/progress/{mediaId}")
    public PlaybackProgressResponse reportProgress(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable String mediaId,
            @RequestBody PlaybackReportRequest request) {
        return service.reportProgress(UUID.fromString(jwt.getSubject()), input.uuid(mediaId, "mediaId"), request);
    }
}
