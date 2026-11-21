package com.omniplay.auth;

import java.util.UUID;
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
        try {
            String hash = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(value.getBytes(StandardCharsets.UTF_8)));
            return new IssuedRefreshToken(value, hash);
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is unavailable", exception);
        }
    }

    public record IssuedRefreshToken(String value, String hash) {
        @Override public String toString() { return "IssuedRefreshToken[redacted]"; }
    }
}
