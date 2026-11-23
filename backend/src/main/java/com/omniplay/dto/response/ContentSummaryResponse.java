package com.omniplay.dto.response;

import com.omniplay.catalog.ContentType;
import java.util.List;
import java.util.UUID;

public record ContentSummaryResponse(UUID id, ContentType type, String title, String description,
        String thumbnailUrl, Integer durationSeconds, List<UUID> genreIds, boolean saved) {
    public ContentSummaryResponse { genreIds = List.copyOf(genreIds); }
}
