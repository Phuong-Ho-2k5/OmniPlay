package com.omniplay.dto.response;

import com.omniplay.catalog.ContentType;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record DailyQuestSetResponse(
        UUID questSetId,
        LocalDate questDate,
        Instant issuedAt,
        Instant expiresAt,
        List<DailyQuestItemResponse> quests) {
    public DailyQuestSetResponse {
        quests = List.copyOf(quests);
    }

    public record DailyQuestItemResponse(
            UUID id,
            String code,
            String title,
            int slot,
            String sourceScope,
            ContentType mediaType,
            int targetCount,
            int progressCount,
            String status,
            int xpReward,
            List<UUID> eligibleMediaIds) {
        public DailyQuestItemResponse {
            eligibleMediaIds = List.copyOf(eligibleMediaIds);
        }
    }
}
