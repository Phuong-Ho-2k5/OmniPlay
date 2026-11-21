package com.omniplay.dto.request;

public record RegisterRequest(String email, String password, String displayName) {
    @Override public String toString() { return "RegisterRequest[redacted]"; }
}
