package com.omniplay.auth;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

@ConfigurationProperties("omniplay.auth")
public record AuthProperties(String jwtSecretBase64, @DefaultValue("omniplay-backend") String issuer,
        @DefaultValue("omniplay-mobile") String audience) {
    @Override public String toString() { return "AuthProperties[redacted]"; }
}
