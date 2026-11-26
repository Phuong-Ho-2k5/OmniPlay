package com.omniplay.dto.response;

import java.util.List;
import java.util.UUID;

public record PlaylistDetailResponse(UUID id, String name, List<PlaylistItemResponse> items) {
    public record PlaylistItemResponse(
            UUID playlistItemId,
            UUID mediaId,
            String title,
            int position,
            int skipCount,
            boolean available) {}
}
