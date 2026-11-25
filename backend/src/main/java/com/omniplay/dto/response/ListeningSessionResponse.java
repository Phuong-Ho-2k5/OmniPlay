package com.omniplay.dto.response;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record ListeningSessionResponse(
        String type,
        UUID currentMediaId,
        BigDecimal positionSeconds,
        boolean isPaused,
        List<QueueItem> queue) {
    public record QueueItem(UUID mediaId, int position) {}
}
