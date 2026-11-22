package com.omniplay.auth;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Embeddable
public class AuthRefreshHistoryId implements Serializable {
    private static final long serialVersionUID = 1L;

    @Column(name = "auth_session_id", nullable = false)
    private UUID authSessionId;

    @Column(name = "token_hash", nullable = false, length = 64, columnDefinition = "char(64)")
    @JdbcTypeCode(SqlTypes.CHAR)
    private String tokenHash;

    protected AuthRefreshHistoryId() {}

    public AuthRefreshHistoryId(UUID authSessionId, String tokenHash) {
        this.authSessionId = authSessionId;
        this.tokenHash = tokenHash;
    }

    public UUID getAuthSessionId() { return authSessionId; }
    public String getTokenHash() { return tokenHash; }

    @Override public boolean equals(Object other) {
        return this == other || other instanceof AuthRefreshHistoryId id
                && Objects.equals(authSessionId, id.authSessionId) && Objects.equals(tokenHash, id.tokenHash);
    }

    @Override public int hashCode() { return Objects.hash(authSessionId, tokenHash); }
}
