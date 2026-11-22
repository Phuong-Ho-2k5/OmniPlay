package com.omniplay.auth;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "auth_sessions")
public class AuthSession {
    @Id
    @Column(name = "auth_session_id", nullable = false)
    private UUID authSessionId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "current_token_hash", nullable = false, length = 64, columnDefinition = "char(64)")
    @JdbcTypeCode(SqlTypes.CHAR)
    private String currentTokenHash;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "rotated_at")
    private Instant rotatedAt;

    @Column(name = "revoked_at")
    private Instant revokedAt;

    protected AuthSession() {}

    public static AuthSession start(UUID sessionId, UUID userId, String tokenHash, Instant createdAt) {
        var session = new AuthSession();
        session.authSessionId = sessionId;
        session.userId = userId;
        session.currentTokenHash = tokenHash;
        session.createdAt = createdAt.truncatedTo(ChronoUnit.MICROS);
        session.expiresAt = session.createdAt.plus(168, ChronoUnit.HOURS);
        return session;
    }

    public UUID getAuthSessionId() { return authSessionId; }
    public UUID getUserId() { return userId; }
    public String getCurrentTokenHash() { return currentTokenHash; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getExpiresAt() { return expiresAt; }
    public Instant getRotatedAt() { return rotatedAt; }
    public Instant getRevokedAt() { return revokedAt; }

    public void rotate(String tokenHash, Instant now) {
        currentTokenHash = tokenHash;
        rotatedAt = now.truncatedTo(ChronoUnit.MICROS);
    }

    public void revoke(Instant now) {
        if (revokedAt == null) revokedAt = now.truncatedTo(ChronoUnit.MICROS);
    }
}
