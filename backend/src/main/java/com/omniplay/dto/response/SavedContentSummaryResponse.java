package com.omniplay.dto.response;

import com.omniplay.catalog.ContentType;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record SavedContentSummaryResponse(
        UUID id,
        ContentType type,
        String title,
        String description,
        String thumbnailUrl,
        Integer durationSeconds,
        List<UUID> genreIds,
        boolean saved,
        boolean available,
        Instant savedAt) {}
