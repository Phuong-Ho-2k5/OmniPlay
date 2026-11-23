package com.omniplay.catalog;

import com.omniplay.common.error.ApiException;
import com.omniplay.common.error.ErrorCode;
import java.util.Map;
import java.util.UUID;
import org.springframework.stereotype.Component;

@Component
public class CatalogInputValidator {
    public CatalogQuery parse(String q, String type, String genreId, String page, String size, boolean requireType) {
        String keyword = q == null ? "" : q.strip();
        if (keyword.codePointCount(0, keyword.length()) > 200) invalid("q", "Từ khóa tối đa 200 ký tự.");
        ContentType contentType = null;
        if (type != null) {
            try { contentType = ContentType.valueOf(type); }
            catch (IllegalArgumentException e) { invalid("type", "Loại nội dung không hợp lệ."); }
        } else if (requireType) {
            invalid("type", "Vui lòng chọn loại nội dung.");
        }
        return new CatalogQuery(keyword, contentType, genreId == null ? null : uuid(genreId, "genreId"),
                integer(page, 0, 0, Integer.MAX_VALUE, "page"), integer(size, 20, 1, 50, "size"));
    }

    public UUID uuid(String value, String field) {
        if (value == null || !value.matches("[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")) {
            invalid(field, "ID phải là UUID hợp lệ.");
        }
        return UUID.fromString(value);
    }

    private int integer(String raw, int fallback, int min, int max, String field) {
        if (raw == null) return fallback;
        try {
            if (!raw.matches("[0-9]+")) throw new NumberFormatException();
            int value = Integer.parseInt(raw);
            if (value < min || value > max) throw new NumberFormatException();
            return value;
        } catch (NumberFormatException e) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR,
                    Map.of(field, "Giá trị phải là số nguyên từ " + min + " đến " + max + "."));
        }
    }

    private void invalid(String field, String message) {
        throw new ApiException(ErrorCode.VALIDATION_ERROR, Map.of(field, message));
    }
}
