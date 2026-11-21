package com.omniplay.auth;

import java.time.Instant;
import java.util.UUID;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import java.time.temporal.ChronoUnit;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class AccessTokenService {
    private final JwtEncoder encoder;
    private final AuthProperties properties;

    public AccessTokenService(JwtEncoder encoder, AuthProperties properties) {
        this.encoder = encoder;
        this.properties = properties;
    }

    public String issue(UUID user, UUID session, Instant time) {
        Instant issuedAt = time.truncatedTo(ChronoUnit.SECONDS);
        var claims = JwtClaimsSet.builder().issuer(properties.issuer()).audience(List.of(properties.audience()))
                .subject(user.toString()).claim("sid", session.toString()).issuedAt(issuedAt)
                .expiresAt(issuedAt.plusSeconds(900)).build();
        var header = JwsHeader.with(MacAlgorithm.HS256).type("JWT").build();
        return encoder.encode(JwtEncoderParameters.from(header, claims)).getTokenValue();
    }
}
