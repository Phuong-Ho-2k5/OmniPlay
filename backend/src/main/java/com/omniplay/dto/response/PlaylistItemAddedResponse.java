package com.omniplay.dto.response;

import java.util.UUID;

public record PlaylistItemAddedResponse(UUID playlistItemId, UUID mediaId, int position) {}
