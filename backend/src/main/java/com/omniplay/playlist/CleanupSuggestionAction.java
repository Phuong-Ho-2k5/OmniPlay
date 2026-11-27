package com.omniplay.playlist;

import com.omniplay.common.error.ApiException;
import com.omniplay.common.error.ErrorCode;
import java.util.Map;

public enum CleanupSuggestionAction {
    KEEP,
    DISMISS,
    REMOVE;

    public static CleanupSuggestionAction parse(String raw) {
        if (raw == null || raw.isBlank()) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR,
                    Map.of("action", "Hành động phải là KEEP, DISMISS hoặc REMOVE."));
        }
        try {
            return CleanupSuggestionAction.valueOf(raw.trim());
        } catch (IllegalArgumentException e) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR,
                    Map.of("action", "Hành động phải là KEEP, DISMISS hoặc REMOVE."));
        }
    }
}
