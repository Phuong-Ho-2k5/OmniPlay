package com.omniplay.dto.response;

import com.omniplay.catalog.ContentType;
import java.math.BigDecimal;
import java.util.UUID;

public record PlaybackMetadataResponse(
        UUID mediaId,
        ContentType type,
        int durationSeconds,
        BigDecimal resumePositionSeconds,
        boolean completed,
        String streamPath) {}
