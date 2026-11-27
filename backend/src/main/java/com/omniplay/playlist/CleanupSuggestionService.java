package com.omniplay.playlist;

import com.omniplay.common.error.ApiException;
import com.omniplay.common.error.ErrorCode;
import com.omniplay.dto.request.CleanupSuggestionActionRequest;
import com.omniplay.dto.response.CleanupSuggestionActionResponse;
import com.omniplay.dto.response.CleanupSuggestionListResponse;
import java.time.Clock;
import java.util.Map;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CleanupSuggestionService {
    private final CleanupSuggestionRepository repository;
    private final Clock clock;

    public CleanupSuggestionService(CleanupSuggestionRepository repository, Clock clock) {
        this.repository = repository;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public CleanupSuggestionListResponse list(UUID userId) {
        return new CleanupSuggestionListResponse(repository.findVisibleByUser(userId));
    }

    @Transactional
    public CleanupSuggestionActionResponse applyAction(
            UUID userId,
            UUID playlistItemId,
            CleanupSuggestionActionRequest request) {
        if (request == null) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR,
                    Map.of("action", "Hành động phải là KEEP, DISMISS hoặc REMOVE."));
        }
        CleanupSuggestionAction action = CleanupSuggestionAction.parse(request.action());

        // Canonical lock order: users -> playlist_items
        if (!repository.lockUser(userId)) {
            throw new ApiException(ErrorCode.NOT_FOUND);
        }

        var lockedOpt = repository.lockItemWithOwner(playlistItemId);
        if (lockedOpt.isEmpty()) {
            if (action == CleanupSuggestionAction.REMOVE) {
                return new CleanupSuggestionActionResponse(playlistItemId, true, 0, false);
            }
            throw new ApiException(ErrorCode.NOT_FOUND);
        }

        var item = lockedOpt.get();
        if (!item.userId().equals(userId)) {
            throw new ApiException(ErrorCode.NOT_FOUND);
        }

        return switch (action) {
            case KEEP -> {
                repository.resetSkipCount(playlistItemId);
                yield new CleanupSuggestionActionResponse(playlistItemId, false, 0, false);
            }
            case DISMISS -> {
                repository.dismissSuggestion(playlistItemId);
                yield new CleanupSuggestionActionResponse(playlistItemId, false, item.skipCount(), false);
            }
            case REMOVE -> {
                repository.removeItem(playlistItemId, item.playlistId(), clock.instant());
                yield new CleanupSuggestionActionResponse(playlistItemId, true, 0, false);
            }
        };
    }
}
