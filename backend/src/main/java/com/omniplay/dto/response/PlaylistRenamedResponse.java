package com.omniplay.dto.response;

import java.time.Instant;
import java.util.UUID;

public record PlaylistRenamedResponse(UUID id, String name, Instant updatedAt) {}
