package com.omniplay.auth;

import com.omniplay.common.error.ErrorCode;
import com.omniplay.dto.response.TokenPairResponse;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Clock;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class RefreshRotationService {
    private final AuthSessionRepository sessions;
    private final AuthRefreshHistoryRepository history;
    private final RefreshTokenFactory refreshTokens;
    private final AccessTokenService accessTokens;
    private final Clock clock;

    public RefreshRotationService(AuthSessionRepository sessions, AuthRefreshHistoryRepository history,
            RefreshTokenFactory refreshTokens, AccessTokenService accessTokens, Clock clock) {
        this.sessions = sessions;
        this.history = history;
        this.refreshTokens = refreshTokens;
        this.accessTokens = accessTokens;
        this.clock = clock;
    }

    /** Call through the Spring proxy; map a rejection to an HTTP error only after this transaction commits. */
    @Transactional
    public RefreshResult rotate(String token) {
        var sessionId = refreshTokens.parse(token);
        if (sessionId.isEmpty()) return invalid();
        var session = sessions.findByIdForUpdate(sessionId.get()).orElse(null);
        if (session == null || session.getRevokedAt() != null) return invalid();

        // Read the clock after acquiring the row lock: a waiting request may cross expiresAt.
        var now = clock.instant();
        String tokenHash = refreshTokens.hash(token);
        boolean current = MessageDigest.isEqual(tokenHash.getBytes(StandardCharsets.US_ASCII),
                session.getCurrentTokenHash().getBytes(StandardCharsets.US_ASCII));
        if (!current) {
            if (history.existsById(new AuthRefreshHistoryId(session.getAuthSessionId(), tokenHash))) {
                session.revoke(now);
            }
            // Return normally so replay revocation commits instead of rolling back with an exception.
            return invalid();
        }
        if (!now.isBefore(session.getExpiresAt())) {
            return new RefreshResult.Rejected(ErrorCode.REFRESH_TOKEN_EXPIRED);
        }

        var replacement = refreshTokens.create(session.getAuthSessionId());
        history.save(AuthRefreshHistory.consumed(session.getAuthSessionId(), tokenHash, now));
        session.rotate(replacement.hash(), now);
        String access = accessTokens.issue(session.getUserId(), session.getAuthSessionId(), now);
        return new RefreshResult.Success(new TokenPairResponse(access, replacement.value(), "Bearer", 900,
                session.getExpiresAt()));
    }

    private static RefreshResult.Rejected invalid() { return new RefreshResult.Rejected(ErrorCode.REFRESH_TOKEN_INVALID); }
}
