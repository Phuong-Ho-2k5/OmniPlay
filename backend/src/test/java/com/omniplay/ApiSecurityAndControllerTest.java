package com.omniplay;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.omniplay.auth.AccessTokenService;
import com.omniplay.auth.AuthAuthenticationEntryPoint;
import com.omniplay.auth.AuthController;
import com.omniplay.auth.AuthService;
import com.omniplay.catalog.CatalogController;
import com.omniplay.catalog.CatalogInputValidator;
import com.omniplay.catalog.CatalogService;
import com.omniplay.catalog.ContentType;
import com.omniplay.catalog.GenreController;
import com.omniplay.catalog.ThumbnailController;
import com.omniplay.catalog.ThumbnailService;
import com.omniplay.common.error.ApiErrorWriter;
import com.omniplay.common.error.ApiException;
import com.omniplay.common.error.ErrorCode;
import com.omniplay.common.error.GlobalExceptionHandler;
import com.omniplay.config.JsonConfig;
import com.omniplay.config.JwtConfig;
import com.omniplay.config.SecurityConfig;
import com.omniplay.dto.response.ContentDetailResponse;
import com.omniplay.dto.response.ContentSummaryResponse;
import com.omniplay.dto.response.GenreListResponse;
import com.omniplay.dto.response.GenreResponse;
import com.omniplay.dto.response.PageResponse;
import com.omniplay.dto.response.RegisteredUserResponse;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(controllers = {
        AuthController.class,
        CatalogController.class,
        GenreController.class,
        ThumbnailController.class
})
@Import({
        SecurityConfig.class,
        JwtConfig.class,
        JsonConfig.class,
        GlobalExceptionHandler.class,
        ApiErrorWriter.class,
        AuthAuthenticationEntryPoint.class,
        AccessTokenService.class,
        CatalogInputValidator.class,
        ApiSecurityAndControllerTest.FixedClockConfig.class
})
@TestPropertySource(properties = {
        "omniplay.auth.jwt-secret-base64=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=",
        "omniplay.auth.issuer=omniplay-backend",
        "omniplay.auth.audience=omniplay-mobile"
})
class ApiSecurityAndControllerTest {
    private static final Instant FIXED_NOW = Instant.parse("2026-11-23T12:00:00Z");

    @TestConfiguration
    static class FixedClockConfig {
        @Bean
        Clock clock() {
            return Clock.fixed(FIXED_NOW, ZoneOffset.UTC);
        }
    }

    @Autowired private MockMvc mvc;
    @Autowired private AccessTokenService accessTokens;

    @MockitoBean private AuthService authService;
    @MockitoBean private CatalogService catalogService;
    @MockitoBean private ThumbnailService thumbnailService;

    @Test
    void publicAuthEndpointsIgnoreBrokenBearerHeaderAndReturnContractStatuses() throws Exception {
        UUID userId = UUID.randomUUID();
        when(authService.register(any()))
                .thenReturn(new RegisteredUserResponse(userId, "user@example.com", "User"));

        mvc.perform(post("/auth/register")
                        .header("Authorization", "Bearer completely.broken.token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"user@example.com\",\"password\":\"ValidPass123!\",\"displayName\":\"User\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.userId").value(userId.toString()));

        mvc.perform(post("/auth/logout")
                        .header("Authorization", "Bearer expired.or.invalid")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"refreshToken\":\"any-string\"}"))
                .andExpect(status().isNoContent())
                .andExpect(content().string(""));
    }

    @Test
    void protectedEndpointsRejectMissingAndExpiredTokensWithExactCodes() throws Exception {
        UUID userId = UUID.randomUUID();
        UUID sessionId = UUID.randomUUID();
        String expiredToken = accessTokens.issue(userId, sessionId, FIXED_NOW.minusSeconds(900));

        // Missing token -> 401 ACCESS_TOKEN_INVALID
        mvc.perform(get("/catalog"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("ACCESS_TOKEN_INVALID"));

        mvc.perform(get("/genres"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("ACCESS_TOKEN_INVALID"));

        mvc.perform(get("/media/" + UUID.randomUUID() + "/thumbnail"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("ACCESS_TOKEN_INVALID"));

        // Expired valid JWT -> 401 ACCESS_TOKEN_EXPIRED
        mvc.perform(get("/catalog").header("Authorization", "Bearer " + expiredToken))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("ACCESS_TOKEN_EXPIRED"));

        mvc.perform(get("/media/" + UUID.randomUUID() + "/thumbnail")
                        .header("Authorization", "Bearer " + expiredToken))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("ACCESS_TOKEN_EXPIRED"));
    }

    @Test
    void authenticatedCatalogGenresDetailAndThumbnailWorkAndValidateErrors() throws Exception {
        UUID userId = UUID.randomUUID();
        UUID sessionId = UUID.randomUUID();
        UUID mediaId = UUID.randomUUID();
        UUID genreId = UUID.randomUUID();
        String token = accessTokens.issue(userId, sessionId, FIXED_NOW.minusSeconds(10));

        var summary = new ContentSummaryResponse(mediaId, ContentType.VIDEO, "Demo Video", "Desc",
                "/media/" + mediaId + "/thumbnail", 12, List.of(genreId), true);
        when(catalogService.list(eq(userId), any()))
                .thenReturn(new PageResponse<>(List.of(summary), 0, 20, 1));
        when(catalogService.genres())
                .thenReturn(new GenreListResponse(List.of(new GenreResponse(genreId, "Công nghệ"))));
        when(catalogService.detail(userId, mediaId, ContentType.VIDEO))
                .thenReturn(new ContentDetailResponse(mediaId, ContentType.VIDEO, "Demo Video", "Desc",
                        "/media/" + mediaId + "/thumbnail", 12, List.of(genreId), true, null));

        byte[] png = {(byte) 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a};
        when(thumbnailService.load(mediaId)).thenReturn(new ThumbnailService.Thumbnail(png, MediaType.IMAGE_PNG));

        mvc.perform(get("/catalog").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.items[0].saved").value(true));

        mvc.perform(get("/genres").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].name").value("Công nghệ"));

        mvc.perform(get("/catalog/" + mediaId).param("type", "VIDEO")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Demo Video"));

        // Missing type on detail -> 400 VALIDATION_ERROR with fieldErrors.type
        mvc.perform(get("/catalog/" + mediaId).header("Authorization", "Bearer " + token))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.fieldErrors.type").exists());

        // Unavailable content -> 404 CONTENT_UNAVAILABLE
        UUID missingId = UUID.randomUUID();
        when(catalogService.detail(userId, missingId, ContentType.POST))
                .thenThrow(new ApiException(ErrorCode.CONTENT_UNAVAILABLE));
        mvc.perform(get("/catalog/" + missingId).param("type", "POST")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("CONTENT_UNAVAILABLE"));

        // Authenticated thumbnail returns bytes + Cache-Control: private, no-store
        mvc.perform(get("/media/" + mediaId + "/thumbnail").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(header().string("Cache-Control", "no-store, private"))
                .andExpect(content().contentType(MediaType.IMAGE_PNG))
                .andExpect(content().bytes(png));
    }
}
