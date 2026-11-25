package com.omniplay.playback;

import com.omniplay.catalog.ContentType;
import com.omniplay.common.error.ApiException;
import com.omniplay.common.error.ErrorCode;
import java.util.Map;

public enum ListeningSessionType {
    MUSIC("music", "MUSIC", ContentType.MUSIC),
    PODCAST("podcast", "PODCAST", ContentType.PODCAST);

    private final String apiValue;
    private final String dbValue;
    private final ContentType mediaType;

    ListeningSessionType(String apiValue, String dbValue, ContentType mediaType) {
        this.apiValue = apiValue;
        this.dbValue = dbValue;
        this.mediaType = mediaType;
    }

    public String apiValue() { return apiValue; }
    public String dbValue() { return dbValue; }
    public ContentType mediaType() { return mediaType; }

    public static ListeningSessionType parse(String raw) {
        if ("music".equals(raw)) return MUSIC;
        if ("podcast".equals(raw)) return PODCAST;
        throw new ApiException(ErrorCode.VALIDATION_ERROR,
                Map.of("type", "Loại phiên nghe phải là music hoặc podcast."));
    }
}
