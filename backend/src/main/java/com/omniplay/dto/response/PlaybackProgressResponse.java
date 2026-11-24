package com.omniplay.dto.response;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record PlaybackProgressResponse(
        UUID mediaId,
        BigDecimal resumePositionSeconds,
        BigDecimal coveredSeconds,
        boolean completed,
        List<QuestUpdate> questUpdates) {
    public record QuestUpdate(UUID questId, int progressCount, String status) {}
}
