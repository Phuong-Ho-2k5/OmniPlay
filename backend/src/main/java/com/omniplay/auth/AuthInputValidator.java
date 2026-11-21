package com.omniplay.auth;

import com.omniplay.dto.request.RegisterRequest;
import com.omniplay.dto.request.LoginRequest;
import com.omniplay.common.error.ApiException;
import com.omniplay.common.error.ErrorCode;
import jakarta.validation.Validator;
import jakarta.validation.constraints.Email;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Locale;
import org.springframework.stereotype.Component;

@Component
public class AuthInputValidator {
    private final Validator validator;

    public AuthInputValidator(Validator validator) {
        this.validator = validator;
    }

    public LoginRequest normalizeAndValidate(LoginRequest input) {
        String email = normalizeEmail(input.email());
        var fields = new LinkedHashMap<String, String>();
        validateCredentials(email, input.password(), fields);
        if (!fields.isEmpty()) throw new ApiException(ErrorCode.VALIDATION_ERROR, fields);
        return new LoginRequest(email, input.password());
    }

    public RegisterRequest normalizeAndValidate(RegisterRequest input) {
        String email = normalizeEmail(input.email());
        String name = input.displayName() == null ? "" : input.displayName().trim();
        String password = input.password();
        var fields = new LinkedHashMap<String, String>();

        validateCredentials(email, password, fields);
        if (name.isBlank() || !isDatabaseText(name) || codePoints(name) > 100) {
            fields.put("displayName", "Tên hiển thị phải có từ 1 đến 100 ký tự.");
        }
        if (!fields.isEmpty()) throw new ApiException(ErrorCode.VALIDATION_ERROR, fields);
        return new RegisterRequest(email, password, name);
    }

    private static String normalizeEmail(String email) {
        return email == null ? "" : email.trim().toLowerCase(Locale.ROOT);
    }

    private void validateCredentials(String email, String password, java.util.Map<String, String> fields) {
        if (email.isBlank() || !isDatabaseText(email) || codePoints(email) > 255
                || !validator.validate(new EmailValue(email)).isEmpty()) {
            fields.put("email", "Email phải đúng định dạng và không quá 255 ký tự.");
        }
        if (password == null || !isUnicode(password) || codePoints(password) < 8
                || password.getBytes(StandardCharsets.UTF_8).length > 72) {
            fields.put("password", "Mật khẩu phải có ít nhất 8 ký tự và không quá 72 byte UTF-8.");
        }
    }

    private static int codePoints(String value) { return value.codePointCount(0, value.length()); }

    private static boolean isUnicode(String value) { return StandardCharsets.UTF_8.newEncoder().canEncode(value); }

    private static boolean isDatabaseText(String value) { return value.indexOf('\0') < 0 && isUnicode(value); }

    private record EmailValue(@Email String value) {}
}
