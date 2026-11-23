package com.omniplay.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.omniplay.common.error.ApiException;
import com.omniplay.common.error.ErrorCode;
import com.omniplay.dto.request.LoginRequest;
import com.omniplay.dto.request.RegisterRequest;
import jakarta.validation.Validation;
import java.nio.charset.StandardCharsets;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class AuthInputValidatorAndTokenTest {
    private AuthInputValidator validator;
    private RefreshTokenFactory refreshTokens;

    @BeforeEach
    void setUp() {
        validator = new AuthInputValidator(Validation.buildDefaultValidatorFactory().getValidator());
        refreshTokens = new RefreshTokenFactory();
    }

    @Test
    void registerNormalizesEmailAndDisplayNameWithoutTrimmingPassword() {
        var result = validator.normalizeAndValidate(
                new RegisterRequest("  Player.One@Example.COM  ", "  Pass123! ", "  Player One  "));
        assertThat(result.email()).isEqualTo("player.one@example.com");
        assertThat(result.password()).isEqualTo("  Pass123! ");
        assertThat(result.displayName()).isEqualTo("Player One");
    }

    @Test
    void registerRejectsShortPasswordAndOver72Utf8BytesAndNul() {
        assertThatThrownBy(() -> validator.normalizeAndValidate(
                new RegisterRequest("bad-email", "short", "   ")))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> {
                    var api = (ApiException) ex;
                    assertThat(api.code()).isEqualTo(ErrorCode.VALIDATION_ERROR);
                    assertThat(api.fieldErrors()).containsKeys("email", "password", "displayName");
                });

        // 19 4-byte emoji = 76 UTF-8 bytes (> 72 bytes limit)
        String longUtf8Password = "\uD83D\uDE00".repeat(19);
        assertThat(longUtf8Password.getBytes(StandardCharsets.UTF_8).length).isEqualTo(76);
        assertThatThrownBy(() -> validator.normalizeAndValidate(
                new LoginRequest("ok@example.com", longUtf8Password)))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> assertThat(((ApiException) ex).fieldErrors()).containsKey("password"));

        assertThatThrownBy(() -> validator.normalizeAndValidate(
                new RegisterRequest("ok@example.com", "ValidPass123!", "Bad\0Name")))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> assertThat(((ApiException) ex).fieldErrors()).containsKey("displayName"));
    }

    @Test
    void requireRefreshTokenRejectsNullButAllowsEmptyStringForAuthCheck() {
        assertThatThrownBy(() -> validator.requireRefreshToken(null))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> assertThat(((ApiException) ex).fieldErrors()).containsKey("refreshToken"));
        assertThat(validator.requireRefreshToken("")).isEqualTo("");
        assertThat(validator.requireRefreshToken("   ")).isEqualTo("   ");
    }

    @Test
    void refreshTokenFactoryValidatesCanonicalWireFormat() {
        UUID sessionId = UUID.randomUUID();
        var issued = refreshTokens.create(sessionId);

        assertThat(issued.value()).hasSize(80);
        assertThat(issued.hash()).hasSize(64).matches("[0-9a-f]{64}");
        assertThat(refreshTokens.parse(issued.value())).contains(sessionId);
        assertThat(refreshTokens.parse(" " + issued.value())).isEmpty();
        assertThat(refreshTokens.parse(issued.value().toUpperCase())).isEmpty();
        assertThat(refreshTokens.parse("not-a-token")).isEmpty();
    }
}
