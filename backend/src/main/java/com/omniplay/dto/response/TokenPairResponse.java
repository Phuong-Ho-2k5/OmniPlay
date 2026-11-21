package com.omniplay.dto.response;

import java.time.Instant;

public record TokenPairResponse(String accessToken, String refreshToken, String tokenType,
        long accessExpiresIn, Instant refreshExpiresAt) {
    @Override public String toString() { return "TokenPairResponse[redacted]"; }
}
