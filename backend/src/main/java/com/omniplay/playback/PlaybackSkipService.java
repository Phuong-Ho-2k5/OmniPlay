package com.omniplay.playback;

import com.omniplay.catalog.CatalogInputValidator;
import com.omniplay.common.error.ApiException;
import com.omniplay.common.error.ErrorCode;
import com.omniplay.dto.request.RecordSkipRequest;
import com.omniplay.dto.response.PlaybackSkipResponse;
import java.util.Map;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PlaybackSkipService {
    private static final int CLEANUP_SUGGESTION_THRESHOLD = 6;

    private final PlaybackSkipRepository repository;
    private final CatalogInputValidator validator;

    public PlaybackSkipService(PlaybackSkipRepository repository, CatalogInputValidator validator) {
        this.repository = repository;
        this.validator = validator;
    }

    @Transactional
    public PlaybackSkipResponse recordSkip(UUID userId, RecordSkipRequest request) {
        if (request == null) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR, Map.of("attemptId", "Thiếu mã lượt phát."));
        }
        UUID attemptId = validator.uuid(request.attemptId(), "attemptId");

        // Canonical lock order: users -> playlist_items -> playback_attempts
        if (!repository.lockUser(userId)) {
            throw new ApiException(ErrorCode.ATTEMPT_NOT_FOUND);
        }

        var lookup = repository.findAttemptUnlocked(attemptId)
                .filter(a -> a.userId().equals(userId))
                .orElseThrow(() -> new ApiException(ErrorCode.ATTEMPT_NOT_FOUND));

        PlaybackSkipRepository.LockedPlaylistItem lockedItem = null;
        if (lookup.playlistItemId() != null) {
            lockedItem = repository.lockOwnedPlaylistItem(lookup.playlistItemId(), userId).orElse(null);
        }

        var attempt = repository.lockAttempt(attemptId)
                .filter(a -> a.userId().equals(userId))
                .orElseThrow(() -> new ApiException(ErrorCode.ATTEMPT_NOT_FOUND));

        if (attempt.playlistItemId() == null || lockedItem == null) {
            return new PlaybackSkipResponse(null, 0, false, false);
        }

        boolean currentSuggestionVisible = isSuggestionVisible(lockedItem.skipCount(), lockedItem.suggestionDismissed());
        if (attempt.skipRecorded()) {
            return new PlaybackSkipResponse(
                    lockedItem.playlistItemId(),
                    lockedItem.skipCount(),
                    currentSuggestionVisible,
                    false);
        }

        if (!repository.hasNextPlaylistItem(lockedItem.playlistId(), lockedItem.position())) {
            return new PlaybackSkipResponse(
                    lockedItem.playlistItemId(),
                    lockedItem.skipCount(),
                    currentSuggestionVisible,
                    false);
        }

        repository.markAttemptSkipRecorded(attempt.attemptId());
        int updatedSkipCount = repository.incrementSkipCountAndResetDismissed(lockedItem.playlistItemId());
        return new PlaybackSkipResponse(
                lockedItem.playlistItemId(),
                updatedSkipCount,
                updatedSkipCount >= CLEANUP_SUGGESTION_THRESHOLD,
                true);
    }

    private boolean isSuggestionVisible(int skipCount, boolean suggestionDismissed) {
        return skipCount >= CLEANUP_SUGGESTION_THRESHOLD && !suggestionDismissed;
    }
}
