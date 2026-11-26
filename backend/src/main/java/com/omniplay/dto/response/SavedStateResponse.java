package com.omniplay.dto.response;

import com.omniplay.catalog.ContentType;
import java.util.UUID;

public record SavedStateResponse(UUID id, ContentType type, boolean saved) {}
