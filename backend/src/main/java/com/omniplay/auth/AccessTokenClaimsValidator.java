package com.omniplay.auth;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import com.omniplay.common.error.ErrorCode;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jwt.Jwt;

public class AccessTokenClaimsValidator implements OAuth2TokenValidator<Jwt> {
    private final Clock clock;
    private final String issuer;
    private final String audience;

    public AccessTokenClaimsValidator(Clock clock, String issuer, String audience) {
        this.clock = clock; this.issuer = issuer; this.audience = audience;
    }

    @Override public OAuth2TokenValidatorResult validate(Jwt token) {
        var claims = token.getClaims();
        if (!uuid(claims.get("sub")) || !uuid(claims.get("sid")) || !issuer.equals(claims.get("iss"))
                || !(claims.get("aud") instanceof List<?> audiences) || audiences.isEmpty()
                || audiences.stream().anyMatch(value -> !(value instanceof String text) || text.isBlank())
                || !audiences.contains(audience)
                || !(claims.get("iat") instanceof Instant issuedAt) || !(claims.get("exp") instanceof Instant expiresAt)) {
            return failure(ErrorCode.ACCESS_TOKEN_INVALID);
        }
        Instant now = clock.instant();
        if (issuedAt.isAfter(now) || !Duration.between(issuedAt, expiresAt).equals(Duration.ofSeconds(900))) {
            return failure(ErrorCode.ACCESS_TOKEN_INVALID);
        }
        return !now.isBefore(expiresAt) ? failure(ErrorCode.ACCESS_TOKEN_EXPIRED) : OAuth2TokenValidatorResult.success();
    }

    private static boolean uuid(Object value) {
        if (!(value instanceof String text)) return false;
        try { return UUID.fromString(text).toString().equalsIgnoreCase(text); }
        catch (IllegalArgumentException exception) { return false; }
    }
    private static OAuth2TokenValidatorResult failure(ErrorCode code) {
        return OAuth2TokenValidatorResult.failure(new OAuth2Error(code.name(), code.message(), null));
    }
}
