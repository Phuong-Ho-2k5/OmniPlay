package com.omniplay.auth;

import java.util.UUID;
import java.util.Optional;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.HexFormat;
import org.springframework.stereotype.Component;

@Component
public class RefreshTokenFactory {
    private final SecureRandom random = new SecureRandom();

    public IssuedRefreshToken create(UUID sessionId) {
        byte[] secret = new byte[32];
        random.nextBytes(secret);
        String value = sessionId + "." + Base64.getUrlEncoder().withoutPadding().encodeToString(secret);
        return new IssuedRefreshToken(value, hash(value));
    }

    /** Parses the exact, canonical wire format; tokens are never trimmed or normalized. */
    public Optional<UUID> parse(String value) {
        if (value == null || value.length() != 80 || value.charAt(36) != '.') return Optional.empty();
        try {
            String id = value.substring(0, 36);
            UUID sessionId = UUID.fromString(id);
            if (!sessionId.toString().equals(id)) return Optional.empty();
            String secret = value.substring(37);
            byte[] decoded = Base64.getUrlDecoder().decode(secret);
            if (decoded.length != 32 || !Base64.getUrlEncoder().withoutPadding().encodeToString(decoded).equals(secret)) {
                return Optional.empty();
            }
            return Optional.of(sessionId);
        } catch (IllegalArgumentException exception) {
            return Optional.empty();
        }
    }

    public String hash(String value) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is unavailable", exception);
        }
    }

    public record IssuedRefreshToken(String value, String hash) {
        @Override public String toString() { return "IssuedRefreshToken[redacted]"; }
    }
}
