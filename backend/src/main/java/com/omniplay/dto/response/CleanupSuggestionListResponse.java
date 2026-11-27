package com.omniplay.dto.response;

import java.util.List;
import java.util.UUID;

public record CleanupSuggestionListResponse(List<CleanupSuggestionItemResponse> items) {
    public record CleanupSuggestionItemResponse(
            UUID playlistItemId,
            UUID playlistId,
            UUID mediaId,
            String title,
            int skipCount) {}
}
