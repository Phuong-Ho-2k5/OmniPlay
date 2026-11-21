package com.omniplay.auth;

import com.omniplay.common.error.ApiException;
import com.omniplay.common.error.ErrorCode;
import com.omniplay.dto.request.RegisterRequest;
import com.omniplay.dto.request.LoginRequest;
import com.omniplay.dto.response.TokenPairResponse;
import com.omniplay.dto.response.RegisteredUserResponse;
import com.omniplay.user.User;
import com.omniplay.user.UserRepository;
import java.time.Clock;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import org.hibernate.exception.ConstraintViolationException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {
    private final UserRepository users;
    private final AuthInputValidator validator;
    private final PasswordEncoder passwords;
    private final Clock clock;
    private final AuthSessionRepository sessions;
    private final RefreshTokenFactory refreshTokens;
    private final AccessTokenService accessTokens;
    private final String dummyPasswordHash;

    public AuthService(UserRepository users, AuthInputValidator validator, PasswordEncoder passwords, Clock clock,
            AuthSessionRepository sessions, RefreshTokenFactory refreshTokens, AccessTokenService accessTokens) {
        this.users = users;
        this.validator = validator;
        this.passwords = passwords;
        this.clock = clock;
        this.sessions = sessions;
        this.refreshTokens = refreshTokens;
        this.accessTokens = accessTokens;
        this.dummyPasswordHash = passwords.encode(UUID.randomUUID().toString());
    }

    @Transactional
    public RegisteredUserResponse register(RegisterRequest request) {
        var input = validator.normalizeAndValidate(request);
        var user = User.create(UUID.randomUUID(), input.email(), passwords.encode(input.password()),
                input.displayName(), clock.instant());
        try {
            users.saveAndFlush(user);
        } catch (DataIntegrityViolationException exception) {
            for (Throwable cause = exception; cause != null; cause = cause.getCause()) {
                if (cause instanceof ConstraintViolationException constraint
                        && "23505".equals(constraint.getSQLState())
                        && "users_email_key".equals(constraint.getConstraintName())) {
                    throw new ApiException(ErrorCode.EMAIL_ALREADY_USED);
                }
            }
            throw exception;
        }
        return new RegisteredUserResponse(user.getUserId(), user.getEmail(), user.getDisplayName());
    }

    @Transactional
    public TokenPairResponse login(LoginRequest request) {
        var input = validator.normalizeAndValidate(request);
        var user = users.findByEmail(input.email()).orElse(null);
        String hash = user == null ? dummyPasswordHash : user.getPasswordHash();
        boolean matches = passwords.matches(input.password(), hash);
        if (user == null || !matches) throw new ApiException(ErrorCode.INVALID_CREDENTIALS);

        UUID sessionId = UUID.randomUUID();
        var refresh = refreshTokens.create(sessionId);
        var createdAt = clock.instant().truncatedTo(ChronoUnit.MICROS);
        var session = AuthSession.start(sessionId, user.getUserId(), refresh.hash(), createdAt);
        sessions.saveAndFlush(session);
        String access = accessTokens.issue(user.getUserId(), sessionId, createdAt);
        return new TokenPairResponse(access, refresh.value(), "Bearer", 900, session.getExpiresAt());
    }
}
