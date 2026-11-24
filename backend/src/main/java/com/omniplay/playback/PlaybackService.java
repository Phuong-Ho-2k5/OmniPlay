package com.omniplay.playback;

import com.omniplay.common.error.ApiException;
import com.omniplay.common.error.ErrorCode;
import com.omniplay.dto.response.PlaybackMetadataResponse;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class PlaybackService {
    private final PlaybackQueryRepository repository;

    public PlaybackService(PlaybackQueryRepository repository) {
        this.repository = repository;
    }

    public PlaybackMetadataResponse metadata(UUID userId, UUID mediaId) {
        return repository.findPlaybackMetadata(userId, mediaId)
                .orElseThrow(() -> new ApiException(ErrorCode.MEDIA_UNAVAILABLE));
    }
}
