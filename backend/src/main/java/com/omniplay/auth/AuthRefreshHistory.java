package com.omniplay.auth;

import jakarta.persistence.Column;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

@Entity
@Table(name = "auth_refresh_history")
public class AuthRefreshHistory {
    @EmbeddedId
    private AuthRefreshHistoryId id;

    @Column(name = "consumed_at", nullable = false)
    private Instant consumedAt;

    protected AuthRefreshHistory() {}

    public static AuthRefreshHistory consumed(UUID sessionId, String tokenHash, Instant now) {
        var history = new AuthRefreshHistory();
        history.id = new AuthRefreshHistoryId(sessionId, tokenHash);
        history.consumedAt = now.truncatedTo(ChronoUnit.MICROS);
        return history;
    }

    public AuthRefreshHistoryId getId() { return id; }
    public Instant getConsumedAt() { return consumedAt; }
}
