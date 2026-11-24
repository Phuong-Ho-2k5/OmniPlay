package com.omniplay.dto.response;

import java.time.Instant;
import java.util.UUID;

public record PlaybackAttemptResponse(
        UUID attemptId,
        UUID mediaId,
        UUID playlistItemId,
        Instant startedAt) {}
