package com.omniplay.playback;

import com.omniplay.catalog.ContentType;
import com.omniplay.common.error.ApiException;
import com.omniplay.common.error.ErrorCode;
import com.omniplay.config.MediaProperties;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;
import java.util.UUID;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;

@Service
public class MediaStreamService {
    private static final MediaType VIDEO_MP4 = MediaType.parseMediaType("video/mp4");
    private static final MediaType AUDIO_MPEG = MediaType.parseMediaType("audio/mpeg");

    private final PlaybackQueryRepository repository;
    private final MediaProperties properties;

    public MediaStreamService(PlaybackQueryRepository repository, MediaProperties properties) {
        this.repository = repository;
        this.properties = properties;
    }

    public StreamPlan prepare(UUID mediaId, String rangeHeader) {
        var media = repository.findAvailableMediaFile(mediaId)
                .orElseThrow(() -> new ApiException(ErrorCode.MEDIA_UNAVAILABLE));
        if (media.filePath() == null || media.filePath().isBlank()) {
            throw new ApiException(ErrorCode.MEDIA_FILE_MISSING);
        }
        Path resolved;
        long totalLength;
        MediaType contentType;
        try {
            Path root = properties.getRoot().toRealPath();
            Path supplied = Path.of(media.filePath());
            if (supplied.isAbsolute()) {
                throw new ApiException(ErrorCode.MEDIA_FILE_MISSING);
            }
            resolved = root.resolve(supplied).normalize().toRealPath();
            if (!resolved.startsWith(root) || !Files.isRegularFile(resolved)) {
                throw new ApiException(ErrorCode.MEDIA_FILE_MISSING);
            }
            totalLength = Files.size(resolved);
            if (totalLength <= 0) {
                throw new ApiException(ErrorCode.MEDIA_FILE_MISSING);
            }
            contentType = resolveContentType(resolved.getFileName().toString(), media.type());
        } catch (IOException | IllegalArgumentException | SecurityException e) {
            throw new ApiException(ErrorCode.MEDIA_FILE_MISSING);
        }

        if (rangeHeader == null || rangeHeader.isBlank()) {
            return new StreamPlan.Full(resolved, contentType, totalLength);
        }
        return parseSingleByteRange(rangeHeader.trim(), resolved, contentType, totalLength);
    }

    private MediaType resolveContentType(String fileName, ContentType mediaType) {
        String lower = fileName.toLowerCase(Locale.ROOT);
        if (mediaType == ContentType.VIDEO && lower.endsWith(".mp4")) {
            return VIDEO_MP4;
        }
        if ((mediaType == ContentType.MUSIC || mediaType == ContentType.PODCAST) && lower.endsWith(".mp3")) {
            return AUDIO_MPEG;
        }
        throw new ApiException(ErrorCode.MEDIA_FILE_MISSING);
    }

    private StreamPlan parseSingleByteRange(String header, Path path, MediaType contentType, long totalLength) {
        if (!header.regionMatches(true, 0, "bytes=", 0, 6)) {
            return new StreamPlan.Unsatisfiable(totalLength);
        }
        String spec = header.substring(6).trim();
        if (spec.isEmpty() || spec.contains(",")) {
            return new StreamPlan.Unsatisfiable(totalLength);
        }
        int dash = spec.indexOf('-');
        if (dash < 0 || spec.indexOf('-', dash + 1) >= 0) {
            return new StreamPlan.Unsatisfiable(totalLength);
        }
        String startPart = spec.substring(0, dash).trim();
        String endPart = spec.substring(dash + 1).trim();
        try {
            long start;
            long end;
            if (startPart.isEmpty()) {
                // Suffix range: bytes=-<suffix>
                if (endPart.isEmpty()) return new StreamPlan.Unsatisfiable(totalLength);
                long suffix = Long.parseLong(endPart);
                if (suffix <= 0) return new StreamPlan.Unsatisfiable(totalLength);
                start = Math.max(0, totalLength - suffix);
                end = totalLength - 1;
            } else {
                start = Long.parseLong(startPart);
                if (start < 0 || start >= totalLength) {
                    return new StreamPlan.Unsatisfiable(totalLength);
                }
                if (endPart.isEmpty()) {
                    end = totalLength - 1;
                } else {
                    end = Math.min(Long.parseLong(endPart), totalLength - 1);
                    if (end < start) return new StreamPlan.Unsatisfiable(totalLength);
                }
            }
            return new StreamPlan.Partial(path, contentType, start, end, totalLength);
        } catch (NumberFormatException e) {
            return new StreamPlan.Unsatisfiable(totalLength);
        }
    }

    public sealed interface StreamPlan {
        record Full(Path path, MediaType contentType, long totalLength) implements StreamPlan {}
        record Partial(Path path, MediaType contentType, long start, long end, long totalLength) implements StreamPlan {
            public long length() { return end - start + 1; }
        }
        record Unsatisfiable(long totalLength) implements StreamPlan {}
    }
}
