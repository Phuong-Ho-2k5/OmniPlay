package com.omniplay.playback;

import com.omniplay.dto.request.SaveListeningSessionRequest;
import com.omniplay.dto.response.ListeningSessionResponse;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/me/listening-sessions")
public class ListeningSessionController {
    private final ListeningSessionService service;

    public ListeningSessionController(ListeningSessionService service) {
        this.service = service;
    }

    @GetMapping("/{type}")
    public ListeningSessionResponse get(@AuthenticationPrincipal Jwt jwt, @PathVariable String type) {
        return service.getSession(UUID.fromString(jwt.getSubject()), ListeningSessionType.parse(type));
    }

    @PutMapping("/{type}")
    public ListeningSessionResponse save(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable String type,
            @RequestBody SaveListeningSessionRequest request) {
        return service.saveSession(UUID.fromString(jwt.getSubject()), ListeningSessionType.parse(type), request);
    }
}
