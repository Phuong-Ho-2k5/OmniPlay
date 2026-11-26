package com.omniplay.dto.response;

import java.time.Instant;
import java.util.UUID;

public record PlaylistSummaryResponse(
        UUID id,
        String name,
        int itemCount,
        Instant createdAt,
        Instant updatedAt) {}
