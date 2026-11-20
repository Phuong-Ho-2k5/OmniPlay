package com.omniplay.common.error;

import java.util.Map;

public record ApiError(String code, String message, Map<String, String> fieldErrors) {
    public ApiError {
        fieldErrors = Map.copyOf(fieldErrors);
    }

    public static ApiError of(ErrorCode code) {
        return new ApiError(code.name(), code.message(), Map.of());
    }
}
