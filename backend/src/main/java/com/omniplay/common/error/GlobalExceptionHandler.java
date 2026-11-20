package com.omniplay.common.error;

import java.util.Comparator;
import java.util.Map;
import java.util.TreeMap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

@RestControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {
    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(ApiException.class)
    ResponseEntity<ApiError> handleApiException(ApiException exception) {
        return ResponseEntity.status(exception.code().status())
                .body(new ApiError(exception.code().name(), exception.code().message(), exception.fieldErrors()));
    }

    @Override
    protected ResponseEntity<Object> handleMethodArgumentNotValid(MethodArgumentNotValidException exception,
            HttpHeaders headers, HttpStatusCode status, WebRequest request) {
        var fields = new TreeMap<String, String>();
        exception.getBindingResult().getFieldErrors().stream()
                .sorted(Comparator.comparing(FieldError::getField)
                        .thenComparing(error -> message(error)))
                .forEach(error -> fields.putIfAbsent(error.getField(), message(error)));
        return new ResponseEntity<>(new ApiError("VALIDATION_ERROR", ErrorCode.VALIDATION_ERROR.message(), fields),
                headers, status);
    }

    private static String message(FieldError error) {
        return error.getDefaultMessage() == null ? ErrorCode.VALIDATION_ERROR.message() : error.getDefaultMessage();
    }

    @Override
    protected ResponseEntity<Object> handleExceptionInternal(Exception exception, Object body, HttpHeaders headers,
            HttpStatusCode status, WebRequest request) {
        ApiError error = switch (status.value()) {
            case 400 -> ApiError.of(ErrorCode.VALIDATION_ERROR);
            case 404 -> ApiError.of(ErrorCode.NOT_FOUND);
            case 405 -> new ApiError("METHOD_NOT_ALLOWED", "Phương thức không được hỗ trợ.", Map.of());
            case 406 -> new ApiError("NOT_ACCEPTABLE", "Định dạng phản hồi không được hỗ trợ.", Map.of());
            case 415 -> new ApiError("UNSUPPORTED_MEDIA_TYPE", "Định dạng dữ liệu không được hỗ trợ.", Map.of());
            default -> status.is5xxServerError() ? ApiError.of(ErrorCode.INTERNAL_ERROR)
                    : new ApiError("HTTP_ERROR", "Yêu cầu không thể được xử lý.", Map.of());
        };
        return new ResponseEntity<>(error, headers, status);
    }

    @ExceptionHandler(Exception.class)
    ResponseEntity<ApiError> handleUnexpected(Exception exception) {
        // Exception messages can contain credentials or rejected request values.
        log.error("Unexpected request failure ({})", exception.getClass().getName());
        return ResponseEntity.internalServerError().body(ApiError.of(ErrorCode.INTERNAL_ERROR));
    }

    @ExceptionHandler(org.springframework.security.access.AccessDeniedException.class)
    ResponseEntity<ApiError> handleAccessDenied() {
        return ResponseEntity.status(ErrorCode.FORBIDDEN.status()).body(ApiError.of(ErrorCode.FORBIDDEN));
    }
}
