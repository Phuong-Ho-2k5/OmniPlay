package com.omniplay.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.omniplay.common.error.ErrorCode;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class RefreshRotationAndLogoutTest {
    private AuthSessionRepository sessions;
    private AuthRefreshHistoryRepository history;
    private RefreshTokenFactory refreshTokens;
    private AccessTokenService accessTokens;
    private Instant now;
    private RefreshRotationService rotationService;
    private LogoutService logoutService;

    @BeforeEach
    void setUp() {
        sessions = mock(AuthSessionRepository.class);
        history = mock(AuthRefreshHistoryRepository.class);
        refreshTokens = new RefreshTokenFactory();
        accessTokens = mock(AccessTokenService.class);
        now = Instant.parse("2026-11-23T12:00:00Z");
        Clock clock = Clock.fixed(now, ZoneOffset.UTC);
        rotationService = new RefreshRotationService(sessions, history, refreshTokens, accessTokens, clock);
        logoutService = new LogoutService(sessions, history, refreshTokens, clock);
    }

    @Test
    void rotateIssuesNewPairRecordsHistoryAndPreservesOriginalExpiry() {
        UUID userId = UUID.randomUUID();
        UUID sessionId = UUID.randomUUID();
        var original = refreshTokens.create(sessionId);
        Instant createdAt = now.minus(Duration.ofHours(2));
        var session = AuthSession.start(sessionId, userId, original.hash(), createdAt);
        Instant expectedExpiry = session.getExpiresAt();

        when(sessions.findByIdForUpdate(sessionId)).thenReturn(Optional.of(session));
        when(accessTokens.issue(userId, sessionId, now)).thenReturn("new-access-jwt");

        RefreshResult result = rotationService.rotate(original.value());

        assertThat(result).isInstanceOf(RefreshResult.Success.class);
        var pair = ((RefreshResult.Success) result).tokenPair();
        assertThat(pair.accessToken()).isEqualTo("new-access-jwt");
        assertThat(pair.refreshToken()).isNotEqualTo(original.value());
        assertThat(pair.refreshExpiresAt()).isEqualTo(expectedExpiry);
        assertThat(session.getCurrentTokenHash()).isEqualTo(refreshTokens.hash(pair.refreshToken()));
        assertThat(session.getRevokedAt()).isNull();
        verify(history).save(any(AuthRefreshHistory.class));
    }

    @Test
    void replayOfHistoricalTokenRevokesSessionAndRejects() {
        UUID userId = UUID.randomUUID();
        UUID sessionId = UUID.randomUUID();
        var oldToken = refreshTokens.create(sessionId);
        var currentToken = refreshTokens.create(sessionId);
        var session = AuthSession.start(sessionId, userId, currentToken.hash(), now.minus(Duration.ofHours(1)));

        when(sessions.findByIdForUpdate(sessionId)).thenReturn(Optional.of(session));
        when(history.existsById(new AuthRefreshHistoryId(sessionId, oldToken.hash()))).thenReturn(true);

        RefreshResult result = rotationService.rotate(oldToken.value());

        assertThat(result).isEqualTo(new RefreshResult.Rejected(ErrorCode.REFRESH_TOKEN_INVALID));
        assertThat(session.getRevokedAt()).isEqualTo(now);
    }

    @Test
    void wrongSecretNotInHistoryRejectsWithoutRevokingSession() {
        UUID userId = UUID.randomUUID();
        UUID sessionId = UUID.randomUUID();
        var currentToken = refreshTokens.create(sessionId);
        var wrongToken = refreshTokens.create(sessionId);
        var session = AuthSession.start(sessionId, userId, currentToken.hash(), now.minus(Duration.ofHours(1)));

        when(sessions.findByIdForUpdate(sessionId)).thenReturn(Optional.of(session));
        when(history.existsById(new AuthRefreshHistoryId(sessionId, wrongToken.hash()))).thenReturn(false);

        RefreshResult result = rotationService.rotate(wrongToken.value());

        assertThat(result).isEqualTo(new RefreshResult.Rejected(ErrorCode.REFRESH_TOKEN_INVALID));
        assertThat(session.getRevokedAt()).isNull();
    }

    @Test
    void expiredCurrentTokenReturnsRefreshTokenExpired() {
        UUID userId = UUID.randomUUID();
        UUID sessionId = UUID.randomUUID();
        var currentToken = refreshTokens.create(sessionId);
        // Session created exactly 168h ago -> expiresAt == now -> expired
        var session = AuthSession.start(sessionId, userId, currentToken.hash(), now.minus(Duration.ofHours(168)));

        when(sessions.findByIdForUpdate(sessionId)).thenReturn(Optional.of(session));

        RefreshResult result = rotationService.rotate(currentToken.value());

        assertThat(result).isEqualTo(new RefreshResult.Rejected(ErrorCode.REFRESH_TOKEN_EXPIRED));
        assertThat(session.getRevokedAt()).isNull();
    }

    @Test
    void logoutRevokesForCurrentOrHistoryTokenAndIgnoresWrongSecret() {
        UUID userId = UUID.randomUUID();
        UUID sessionId = UUID.randomUUID();
        var currentToken = refreshTokens.create(sessionId);
        var wrongToken = refreshTokens.create(sessionId);
        var session = AuthSession.start(sessionId, userId, currentToken.hash(), now.minus(Duration.ofHours(1)));

        when(sessions.findByIdForUpdate(sessionId)).thenReturn(Optional.of(session));
        when(history.existsById(new AuthRefreshHistoryId(sessionId, wrongToken.hash()))).thenReturn(false);

        // Wrong secret must not revoke
        logoutService.logout(wrongToken.value());
        assertThat(session.getRevokedAt()).isNull();

        // Malformed token must not touch repository
        logoutService.logout("malformed");
        verify(sessions).findByIdForUpdate(sessionId);

        // Current token revokes session
        logoutService.logout(currentToken.value());
        assertThat(session.getRevokedAt()).isEqualTo(now);
        verify(history, never()).save(any());
    }
}
