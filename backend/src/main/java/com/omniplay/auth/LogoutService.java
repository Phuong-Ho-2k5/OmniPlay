package com.omniplay.auth;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Clock;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class LogoutService {
    private final AuthSessionRepository sessions;
    private final AuthRefreshHistoryRepository history;
    private final RefreshTokenFactory refreshTokens;
    private final Clock clock;

    public LogoutService(AuthSessionRepository sessions, AuthRefreshHistoryRepository history,
            RefreshTokenFactory refreshTokens, Clock clock) {
        this.sessions = sessions;
        this.history = history;
        this.refreshTokens = refreshTokens;
        this.clock = clock;
    }

    @Transactional
    public void logout(String token) {
        var sessionId = refreshTokens.parse(token);
        if (sessionId.isEmpty()) return;
        var session = sessions.findByIdForUpdate(sessionId.get()).orElse(null);
        if (session == null) return;

        String tokenHash = refreshTokens.hash(token);
        boolean current = MessageDigest.isEqual(tokenHash.getBytes(StandardCharsets.US_ASCII),
                session.getCurrentTokenHash().getBytes(StandardCharsets.US_ASCII));
        if (current || history.existsById(new AuthRefreshHistoryId(session.getAuthSessionId(), tokenHash))) {
            session.revoke(clock.instant());
        }
    }
}
