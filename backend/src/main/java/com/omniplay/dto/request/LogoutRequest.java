package com.omniplay.dto.request;

public record LogoutRequest(String refreshToken) {
    @Override public String toString() { return "LogoutRequest[redacted]"; }
}
