package com.omniplay.dto.response;

import java.util.UUID;

public record RegisteredUserResponse(UUID userId, String email, String displayName) {}
