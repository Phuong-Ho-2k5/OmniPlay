package com.omniplay.auth;

import com.omniplay.common.error.ErrorCode;
import com.omniplay.dto.response.TokenPairResponse;

public sealed interface RefreshResult {
    record Success(TokenPairResponse tokenPair) implements RefreshResult {
        @Override public String toString() { return "Success[redacted]"; }
    }

    record Rejected(ErrorCode code) implements RefreshResult {}
}
