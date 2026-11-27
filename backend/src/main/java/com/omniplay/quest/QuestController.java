package com.omniplay.quest;

import com.omniplay.catalog.CatalogInputValidator;
import com.omniplay.dto.response.ContentSummaryResponse;
import com.omniplay.dto.response.DailyQuestSetResponse;
import com.omniplay.dto.response.PageResponse;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/me/quests")
public class QuestController {
    private final QuestService service;
    private final CatalogInputValidator input;

    public QuestController(QuestService service, CatalogInputValidator input) {
        this.service = service;
        this.input = input;
    }

    @PostMapping("/today/ensure")
    public DailyQuestSetResponse ensureToday(@AuthenticationPrincipal Jwt jwt) {
        return service.ensureToday(UUID.fromString(jwt.getSubject()));
    }

    @GetMapping("/today")
    public DailyQuestSetResponse getToday(@AuthenticationPrincipal Jwt jwt) {
        return service.getToday(UUID.fromString(jwt.getSubject()));
    }

    @GetMapping("/{questId}/media")
    public PageResponse<ContentSummaryResponse> getQuestMedia(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable String questId,
            @RequestParam(required = false) String page,
            @RequestParam(required = false) String size) {
        var query = input.parse(null, null, null, page, size, false);
        return service.getQuestMedia(
                UUID.fromString(jwt.getSubject()),
                input.uuid(questId, "questId"),
                query.page(),
                query.size());
    }
}
