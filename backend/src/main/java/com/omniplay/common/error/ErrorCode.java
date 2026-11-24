package com.omniplay.common.error;

import org.springframework.http.HttpStatus;

public enum ErrorCode {
    VALIDATION_ERROR(HttpStatus.BAD_REQUEST, "Dữ liệu chưa hợp lệ."),
    EMAIL_ALREADY_USED(HttpStatus.CONFLICT, "Email đã được sử dụng."),
    INVALID_CREDENTIALS(HttpStatus.UNAUTHORIZED, "Email hoặc mật khẩu không đúng."),
    ACCESS_TOKEN_EXPIRED(HttpStatus.UNAUTHORIZED, "Phiên truy cập đã hết hạn."),
    ACCESS_TOKEN_INVALID(HttpStatus.UNAUTHORIZED, "Vui lòng đăng nhập để tiếp tục."),
    REFRESH_TOKEN_INVALID(HttpStatus.UNAUTHORIZED, "Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại."),
    REFRESH_TOKEN_EXPIRED(HttpStatus.UNAUTHORIZED, "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại."),
    FORBIDDEN(HttpStatus.FORBIDDEN, "Bạn không có quyền thực hiện thao tác này."),
    NOT_FOUND(HttpStatus.NOT_FOUND, "Không tìm thấy tài nguyên."),
    CONTENT_UNAVAILABLE(HttpStatus.NOT_FOUND, "Nội dung không tồn tại hoặc đã ngừng phục vụ."),
    MEDIA_UNAVAILABLE(HttpStatus.NOT_FOUND, "Nội dung media không tồn tại hoặc đã ngừng phục vụ."),
    MEDIA_FILE_MISSING(HttpStatus.NOT_FOUND, "Không tìm thấy tệp media trên máy chủ."),
    ATTEMPT_NOT_FOUND(HttpStatus.NOT_FOUND, "Không tìm thấy lượt phát phù hợp."),
    REQUEST_CONFLICT(HttpStatus.CONFLICT, "Yêu cầu trùng mã nhưng khác dữ liệu ban đầu."),
    EVENT_CONFLICT(HttpStatus.CONFLICT, "Sự kiện phát trùng số thứ tự nhưng khác nội dung."),
    INTERNAL_ERROR(HttpStatus.INTERNAL_SERVER_ERROR, "Máy chủ gặp lỗi xử lý."),
    SERVICE_UNAVAILABLE(HttpStatus.SERVICE_UNAVAILABLE, "Dịch vụ tạm thời chưa sẵn sàng.");

    private final HttpStatus status;
    private final String message;

    ErrorCode(HttpStatus status, String message) {
        this.status = status;
        this.message = message;
    }

    public HttpStatus status() { return status; }
    public String message() { return message; }
}
