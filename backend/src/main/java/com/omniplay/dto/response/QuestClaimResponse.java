package com.omniplay.dto.response;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record QuestClaimResponse(
        UUID questId,
        String status,
        int xpAwarded,
        int totalXp,
        int level,
        List<BadgeAwardResponse> newBadges) {
    public QuestClaimResponse {
        newBadges = List.copyOf(newBadges);
    }

    public record BadgeAwardResponse(
            UUID id,
            String name,
            String description,
            int xpThreshold,
            Instant awardedAt) {}
}
