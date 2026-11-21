package com.omniplay.auth;

import com.omniplay.common.error.ApiErrorWriter;
import com.omniplay.common.error.ErrorCode;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.oauth2.jwt.JwtValidationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

@Component
public class AuthAuthenticationEntryPoint implements AuthenticationEntryPoint {
    private final ApiErrorWriter errors;
    public AuthAuthenticationEntryPoint(ApiErrorWriter errors) { this.errors = errors; }

    @Override public void commence(HttpServletRequest request, HttpServletResponse response,
            AuthenticationException exception) throws IOException {
        ErrorCode code = ErrorCode.ACCESS_TOKEN_INVALID;
        for (Throwable cause = exception; cause != null; cause = cause.getCause()) {
            if (cause instanceof JwtValidationException validation && !validation.getErrors().isEmpty()) {
                if (validation.getErrors().stream().allMatch(error -> ErrorCode.ACCESS_TOKEN_EXPIRED.name().equals(error.getErrorCode()))) {
                    code = ErrorCode.ACCESS_TOKEN_EXPIRED;
                }
                break;
            }
        }
        errors.write(response, code);
    }
}
