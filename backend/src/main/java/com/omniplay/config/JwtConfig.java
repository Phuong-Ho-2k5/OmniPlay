package com.omniplay.config;

import com.omniplay.auth.AuthProperties;
import com.omniplay.auth.AccessTokenClaimsValidator;
import com.nimbusds.jwt.SignedJWT;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Bean;
import java.util.Base64;
import java.util.List;
import java.time.Clock;
import java.text.ParseException;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.BadJwtException;

@Configuration
@EnableConfigurationProperties(AuthProperties.class)
public class JwtConfig {
    @Bean
    SecretKey jwtSigningKey(AuthProperties properties) {
        String value = properties.jwtSecretBase64();
        byte[] key;
        try {
            key = value == null ? new byte[0] : Base64.getDecoder().decode(value);
        } catch (IllegalArgumentException exception) {
            throw new IllegalStateException("JWT_SECRET_BASE64 must be valid Base64 encoding at least 32 bytes.");
        }
        if (key.length < 32) {
            throw new IllegalStateException("JWT_SECRET_BASE64 must be valid Base64 encoding at least 32 bytes.");
        }
        if (properties.issuer() == null || properties.issuer().isBlank()
                || properties.audience() == null || properties.audience().isBlank()) {
            throw new IllegalStateException("JWT issuer and audience must not be blank.");
        }
        return new SecretKeySpec(key, "HmacSHA256");
    }

    @Bean
    JwtEncoder jwtEncoder(SecretKey jwtSigningKey) {
        return NimbusJwtEncoder.withSecretKey(jwtSigningKey).algorithm(MacAlgorithm.HS256).build();
    }

    @Bean
    JwtDecoder jwtDecoder(SecretKey jwtSigningKey, AuthProperties properties, Clock clock) {
        var decoder = NimbusJwtDecoder.withSecretKey(jwtSigningKey).macAlgorithm(MacAlgorithm.HS256).build();
        decoder.setJwtValidator(new AccessTokenClaimsValidator(clock, properties.issuer(), properties.audience()));
        return value -> {
            // Check wire types before Nimbus normalizes them. JWT permits a single audience string.
            // Expiration is classified only after signature verification.
            requireClaimTypes(value);
            return decoder.decode(value);
        };
    }

    private static void requireClaimTypes(String value) {
        try {
            var claims = SignedJWT.parse(value).getPayload().toJSONObject();
            if (claims == null || !(claims.get("sub") instanceof String) || !(claims.get("sid") instanceof String)
                    || !(claims.get("iss") instanceof String) || !audienceType(claims.get("aud"))
                    || !epochSeconds(claims.get("iat")) || !epochSeconds(claims.get("exp"))) {
                throw new BadJwtException("Invalid access token claims.");
            }
        } catch (ParseException | IllegalArgumentException exception) {
            throw new BadJwtException("Invalid access token.");
        }
    }

    private static boolean epochSeconds(Object value) { return value instanceof Long || value instanceof Integer; }

    private static boolean audienceType(Object value) {
        return value instanceof String || value instanceof List<?> audiences
                && audiences.stream().allMatch(audience -> audience instanceof String);
    }
}
