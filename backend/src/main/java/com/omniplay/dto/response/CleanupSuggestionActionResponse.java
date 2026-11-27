package com.omniplay.dto.response;

import java.util.UUID;

public record CleanupSuggestionActionResponse(
        UUID playlistItemId,
        boolean removed,
        int skipCount,
        boolean suggestionVisible) {}
