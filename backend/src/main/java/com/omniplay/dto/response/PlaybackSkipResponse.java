package com.omniplay.dto.response;

import java.util.UUID;

public record PlaybackSkipResponse(
        UUID playlistItemId,
        int skipCount,
        boolean suggestionVisible,
        boolean recorded) {}
