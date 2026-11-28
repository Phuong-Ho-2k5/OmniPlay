package com.omniplay.mystery;

import com.omniplay.dto.request.MysteryBoxDrawRequest;
import com.omniplay.dto.response.MysteryBoxDrawResponse;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/mystery-box")
public class MysteryBoxController {
    private final MysteryBoxService service;

    public MysteryBoxController(MysteryBoxService service) {
        this.service = service;
    }

    @PostMapping("/draw")
    public MysteryBoxDrawResponse draw(
            @AuthenticationPrincipal Jwt jwt,
            @RequestBody(required = false) MysteryBoxDrawRequest request) {
        return service.draw(UUID.fromString(jwt.getSubject()), request);
    }
}
