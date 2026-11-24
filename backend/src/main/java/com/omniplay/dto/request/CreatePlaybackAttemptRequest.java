package com.omniplay.dto.request;

public record CreatePlaybackAttemptRequest(
        String attemptId,
        String mediaId,
        String playlistItemId) {}
