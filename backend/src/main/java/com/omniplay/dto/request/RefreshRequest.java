package com.omniplay.dto.request;

public record RefreshRequest(String refreshToken) {
    @Override public String toString() { return "RefreshRequest[redacted]"; }
}
