package com.omniplay.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.omniplay.auth.AccessTokenService;
import com.omniplay.auth.AuthProperties;
import com.omniplay.common.error.ErrorCode;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Base64;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jwt.JwtValidationException;

class JwtConfigTest {
    @Test
    void accessTokenExpiresAtExactBoundaryWithZeroClockSkew() {
        String secret = Base64.getEncoder()
                .encodeToString("0123456789abcdef0123456789abcdef".getBytes(StandardCharsets.UTF_8));
        var props = new AuthProperties(secret, "omniplay-backend", "omniplay-mobile");
        var jwtConfig = new JwtConfig();
        var key = jwtConfig.jwtSigningKey(props);
        var encoder = jwtConfig.jwtEncoder(key);
        var service = new AccessTokenService(encoder, props);

        Instant issuedAt = Instant.parse("2026-11-23T12:00:00Z");
        UUID userId = UUID.randomUUID();
        UUID sessionId = UUID.randomUUID();
        String token = service.issue(userId, sessionId, issuedAt);

        // At issuedAt + 899s: valid
        var validDecoder = jwtConfig.jwtDecoder(key, props,
                Clock.fixed(issuedAt.plusSeconds(899), ZoneOffset.UTC));
        var jwt = validDecoder.decode(token);
        assertThat(jwt.getSubject()).isEqualTo(userId.toString());
        assertThat(jwt.getClaimAsString("sid")).isEqualTo(sessionId.toString());

        // At exact expiry (issuedAt + 900s): ACCESS_TOKEN_EXPIRED (clock skew = 0)
        var expiredDecoder = jwtConfig.jwtDecoder(key, props,
                Clock.fixed(issuedAt.plusSeconds(900), ZoneOffset.UTC));
        assertThatThrownBy(() -> expiredDecoder.decode(token))
                .isInstanceOf(JwtValidationException.class)
                .satisfies(ex -> assertThat(((JwtValidationException) ex).getErrors())
                        .anyMatch(err -> ErrorCode.ACCESS_TOKEN_EXPIRED.name().equals(err.getErrorCode())));

        // Wrong issuer even when expired -> ACCESS_TOKEN_INVALID
        var wrongIssuerProps = new AuthProperties(secret, "other-issuer", "omniplay-mobile");
        var wrongIssuerDecoder = jwtConfig.jwtDecoder(key, wrongIssuerProps,
                Clock.fixed(issuedAt.plusSeconds(900), ZoneOffset.UTC));
        assertThatThrownBy(() -> wrongIssuerDecoder.decode(token))
                .isInstanceOf(JwtValidationException.class)
                .satisfies(ex -> assertThat(((JwtValidationException) ex).getErrors())
                        .anyMatch(err -> ErrorCode.ACCESS_TOKEN_INVALID.name().equals(err.getErrorCode())));
    }
}
