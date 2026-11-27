package com.omniplay.playback;

import com.omniplay.dto.request.RecordSkipRequest;
import com.omniplay.dto.response.PlaybackSkipResponse;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/me")
public class PlaybackSkipController {
    private final PlaybackSkipService service;

    public PlaybackSkipController(PlaybackSkipService service) {
        this.service = service;
    }

    @PostMapping("/playback-skips")
    public PlaybackSkipResponse recordSkip(
            @AuthenticationPrincipal Jwt jwt,
            @RequestBody RecordSkipRequest request) {
        return service.recordSkip(UUID.fromString(jwt.getSubject()), request);
    }
}
